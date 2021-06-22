{ lib, baseInputs, ... }:
let
    inherit (builtins) attrNames attrValues readDir mapAttrs pathExists;
    
    inherit (lib) fold flatten optionalAttrs filterAttrs genAttrs mapAttrs'
        recursiveUpdate nixosSystem substring optional removePrefix;
    inherit (lib.arnix) pkgImport genAttrs' recursiveMerge recursiveMergeAttrsWith recursiveMergeAttrsWithNames
        optionalPath optionalPathImport pathsToImportedAttrs recImportDirs;
    inherit (baseInputs) nixos flake-utils;
in rec {
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = root: inputs: let
        inherit (inputs) self;
        inherit (self._internal) extern overrides;
        inherit (flake-utils.lib) eachDefaultSystem;

        # create a version of lib with our generated packages and inject it
        derivedLib = system: lib.override { pkgs = pkgs.${system}; };

        pkgs = (eachDefaultSystem (system:
            let
                overridePkgs = pkgImport baseInputs.unstable [ ] system overrides.unfree;
                overlays = (map (p: p overridePkgs) overrides.packages)
                ++ [(final: prev: {
                        # add in our sources
                        srcs = inputs.srcs.inputs;

                        # extend the "lib" namespace
                        lib = (prev.lib or { }) // {
                            inherit nixosSystem;
                            arnix = (self.lib or inputs.arnix.lib) // (derivedLib system);
                        };
                })]
                ++ extern.overlays
                ++ (attrValues self.overlays);
            in { pkgs = pkgImport nixos overlays system overrides.unfree; }
        )).pkgs;
    in pkgs;

    # Generates the "packages" flake output
    # overlay + overlays = packages
    genPackagesOutput = root: inputs: pkgs: let
        inherit (inputs.self) overlays;
        
        # grab the package names from all our overlays
        packagesNames = attrNames (fold (attr: sum: recursiveUpdate sum attr) { } (
            attrValues (mapAttrs (_: v: v null null) overlays)
        ));
    in fold (key: sum: recursiveUpdate sum {
        "${key}" = pkgs.${key};
    }) { } packagesNames;

    /**
    Synopsis: mkProfileAttrs _path_

    Recursively import the subdirs of _path_ containing a default.nix.

    Example:
    let profiles = mkProfileAttrs ./profiles; in
    assert profiles ? core.default; 0
    **/
    mkProfileAttrs = dir: let
        imports = let
            files = readDir dir;
            p = n: v: v == "directory" && n != "profiles";
        in filterAttrs p files;

        f = n: _: optionalAttrs (pathExists "${dir}/${n}/default.nix") {
            defaults = [ "${dir}/${n}" ];
        } // mkProfileAttrs "${dir}/${n}";
    in mapAttrs f imports;

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

    # Reduces profile defaults into their parent attributes
    mkProf = profiles: flatten ((map (profile: profile.defaults)) profiles);

    # Retrieves the store path of one of our base inputs
    mkInputStorePath = input: baseInputs.${input}.outPath;

    # Makes a Colmena hive from a system and nodes
    mkColmenaHiveNodes = system: nodes: let
        inherit (baseInputs) colmena;
        inherit (colmena.lib.${system}) mkColmenaHive;
    in mkColmenaHive {
        inherit system nodes;
    };

    # shared repo creation function
    mkInternalArnixRepo = all@{ name, root, inputs, ... }: let
        inherit (flake-utils.lib)
            eachDefaultSystem flattenTreeSystem;
        inherit (inputs) self;

        # list of module paths -> i.e. security/sgx
        # too bad we cannot output actual recursive attribute sets :(
        moduleAttrs = paths: genAttrs' paths (path: {
            name = removePrefix "${toString (root + "/modules")}/" (toString path);
            value = import path;
        });

        overlay = optionalPathImport (root + "/pkgs/default.nix") (final: prev: {});

        # imports all the overlays inside the "overlays" directory
        overlayAttrs = let
            overlayDir = root + "/overlays";
        in optionalPath overlayDir (p:
            let
                fullPath = name: p + "/${name}";
            in pathsToImportedAttrs (
                map fullPath (attrNames (readDir p))
            )
        ) { };

        outputs = rec {
            # shared library functions
            lib = if (inputs ? lib) then inputs.lib
                else optionalPath (root + "/lib") (p: import p {
                    inherit (nixos) lib;
                }) { };

            # this represents the packages we provide
            overlays = overlayAttrs // (genAttrs (attrNames (overlay null null)) (name: (
                final: prev: { "${name}" = (overlay final prev).${name}; }
            )));

            # attrs of all our nixos modules
            nixosModules = let
                cachix = optionalPath (root + "/cachix.nix")
                    (p: { cachix = import (root + "/cachix.nix"); }) { };
                modules = optionalPath (root + "/modules/module-list.nix")
                    (p: moduleAttrs (import p)) { };
            in recursiveUpdate cachix modules;

            # Internal outputs used only for passing to other Arnix repos
            _internal = rec {
                inherit name;

                repos.self = {
                    users = optionalPath (root + "/users") (p: mkProfileAttrs (toString p)) { };
                    profiles = optionalPath (root + "/profiles") (p: (mkProfileAttrs (toString p))) { };
                };

                repos."${name}" = repos.self;

                # import the external input files
                extern = optionalPath (root + "/extern") (p: import p { inherit inputs; }) { };
                overrides = optionalPathImport (root + "/overrides") {
                    unfree = []; modules = []; disabledModules = [];
                    packages = [];
                };
            };
        };

        # Generate per-system outputs
        # i.e. x86_64-linux, aarch64-linux
        systemOutputs = let
            mkEachSystem = f: eachDefaultSystem (system: let
                pkgs = (genPkgs root inputs).${system};
            in f system pkgs);
        in (mkEachSystem (system: pkgs: {
            devShell = pkgs.mkShell self._internal.shell.${system};
            packages = flattenTreeSystem system (genPackagesOutput root inputs pkgs);
        })) // {
            _internal = mkEachSystem (system: pkgs: {
                # this lets children add stuff to the shell
                shell = optionalPath (root + "/shell.nix") (p: import p { inherit pkgs; }) {};
            });
        };
    in recursiveUpdate outputs systemOutputs;

    # Produces flake outputs for the root repository
    mkRootArnixRepo = all@{ inputs, ... }: mkInternalArnixRepo (all // {
        name = "root";
        root = ./..;
    });

    # Produces flake outputs for repositories
    mkArnixRepo = all@{
        name,
        root,
        parent,
        inputs,
        bases ? [],
        flat ? false,
        system ? "x86_64-linux",

        # dynamic result generation functor
        generator ? null
    }: let
        inherit (baseInputs) colmena;
        inherit (inputs) self;

        inherit (colmena.lib.${system}) mkColmenaHive;

        # build the repository
        repo = let
            local = mkInternalArnixRepo (all // { inputs = baseInputs // inputs; });

            # merge together the attrs we need from our parent
            shallowMerged = recursiveMergeAttrsWithNames
                ["nixosModules" "overlays" "packages"] (a: b: a // b) [ parent local ];
            deepMerged = recursiveMergeAttrsWithNames
                ["lib" "_internal"] (a: b: recursiveMerge [ a b ]) [ parent local ];
        in (shallowMerged // deepMerged) // {
            inherit (local) devShell;
        };

        # function to create our host attrs
        mkHosts = { root, flat ? false, bases ? [], modifier ? (_: _) }: rec {
            nixosConfigurations = mkNixosSystems {
                inherit root system bases flat;
                inputs = baseInputs // inputs;
            };

            colmena = mkColmenaHiveNodes system _internal.prefixedNodes;

            # add checks for deploy-rs
            # checks = mapAttrs (system: deployLib:
            #     deployLib.deployChecks self.deploy
            # ) deploy.lib;

            _internal.prefixedNodes = modifier nixosConfigurations;
        };
    in recursiveUpdate repo (
        if (generator != null) then
            generator mkHosts
        else mkHosts {
            inherit root flat bases;
        }
    );

    # Builds a NixOS system
    mkNixosSystem = {
        inputs, # The flake inputs
        pkgs, # The compiled package set

        repos, # Set of Arnix repositories
        nodes, # Set of nodes to allow inter-node resolution

        name, # The hostname of the host
        bases, # The base configurations for the repo
        config, # The base configuration for the host
        system ? "x86_64-linux", # Target system to build for
    }: let
        inherit (inputs) self;
        inherit (self._internal) extern overrides;
    in nixosSystem {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit lib repos name nodes;
        };

        modules = let
            # merge down core profiles from all repos
            core.require = (recursiveMergeAttrsWith (
                a: b: recursiveMerge [ a b ]
            ) (attrValues repos)).profiles.core.defaults;

            global = with lib.arnix.modules; [
                (globalDefaults { inherit inputs pkgs name; })
                (hmDefaults {
                    # TODO: inherit specialArgs, modules
                    specialArgs = {};
                    modules = [];
                })
            ];

            modOverrides = { config, overrideModulesPath, ... }: let
                inherit (overrides) modules disabledModules;
            in {
                disabledModules = modules ++ disabledModules;
                imports = map (path: "${overrideModulesPath}/${path}") modules;
            };

            # Everything in `./modules/list.nix`.
            flakeModules = attrValues (removeAttrs self.nixosModules [ "profiles" ]);
        
        # **** what is being imported here? ****
        # core = profile in `profiles/core` which is always imported
        # global = internal profile which sets up local defaults
        # bases = list of "base" profiles that come from the flake top-level
        # config = the actual host configuration
        # modOverrides = module overrides
        # extern.modules = modules from external flakes
        in flakeModules ++ [ core ] ++ global ++ bases ++ [
            config modOverrides
        ] ++ extern.modules;
    };

    # Builds a set of NixOS systems from the hosts folder
    mkNixosSystems = {
        inputs,
        root,

        system ? "x86_64-linux", # Target system to build for
        bases ? {},
        flat ? false,
    }: let
        # Generate our package set
        pkgs = (genPkgs root inputs).${system};

        config = name: let
            inherit (inputs) self;

            # flat = hosts live in top-level rather than in "hosts" folder
            hostFile = root + (if flat then "/${name}" else "/hosts/${name}");
        in mkNixosSystem {
            inherit inputs pkgs nodes name bases system;
            inherit (self._internal) repos;

            config.require = [ hostFile ];
        };

        # make attrs for each possible host
        nodes = recImportDirs {
            dir = if flat then root else root + "/hosts";
            _import = config;
        };
    in nodes;
}