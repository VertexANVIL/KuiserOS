{ lib, baseInputs, ... }:
let
    inherit (builtins) attrNames attrValues readDir mapAttrs pathExists;
    
    inherit (lib) fold flatten optionalAttrs filterAttrs genAttrs mapAttrs' splitString
        recursiveUpdate substring optional removePrefix nameValuePair makeOverridable hasAttr hasAttrByPath attrByPath assertMsg;
    inherit (lib.arnix) pkgImport genAttrs' recursiveMerge recursiveMergeAttrsWith recursiveMergeAttrsWithNames
        optionalPath optionalPathImport pathsToImportedAttrs recImportDirs;
    inherit (baseInputs) nixos unstable flake-utils;
in rec {
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = root: inputs: let
        inherit (inputs) self;
        inherit (self._internal) extern overrides;
        inherit (flake-utils.lib) eachDefaultSystem;

        # create a version of lib with our generated packages and inject it
        derivedLib = system: lib.arnix.override { pkgs = pkgs.${system}; };

        pkgs = (eachDefaultSystem (system:
            let
                overridePkgs = pkgImport baseInputs.unstable [ ] system overrides.unfree;
                overlays = (map (p: p overridePkgs) overrides.packages)
                ++ [(final: prev: {
                    # add in our sources
                    srcs = inputs.srcs.inputs;

                    # extend the "lib" namespace
                    lib = (prev.lib or { }) // {
                        arnix = derivedLib system;
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

    # Creates a special library version specific to NixOS configurations
    nixosLib = { inputs, pkgs, ... }: let
        inherit (inputs) self;
        inherit (self._internal) users profiles;

        attrs = {
            # Constructs everything we need for a profile
            mkProfile = attrs: let
                pathToTarget = src: path: let
                    p = splitString "/" path;
                    result = attrByPath p null src;
                in
                    assert (assertMsg (result != null) "The profile \"${path}\" does not exist.");
                result;

                pathsToTarget = src: paths: map (p: pathToTarget src p) paths;
                profileDefaults = profiles: flatten ((map (p: p.defaults)) profiles);

                requires = {
                    users = pathsToTarget users (flatten (attrs.requires.users or []));
                    profiles = pathsToTarget profiles (flatten (attrs.requires.profiles or []));
                };
            in (filterAttrs (n: v: n != "requires") attrs) // {
                imports = (attrs.imports or [])
                    ++ (profileDefaults requires.users)
                    ++ (profileDefaults requires.profiles);

                # set up our configuration for introspection use
                arnix = {
                    users = map (p: p._name) requires.users;
                    profiles = map (p: p._name) requires.profiles;
                };
            };
        };

        overridden = lib.arnix.override { inherit pkgs; };
        final = overridden.extend attrs;
    in lib // {
        arnix = final;
    };

    /**
    Synopsis: mkProfileAttrs _path_

    Recursively import the subdirs of _path_ containing a default.nix.

    Example:
    let profiles = mkProfileAttrs ./profiles; in
    assert profiles ? core.default; 0
    **/
    mkProfileAttrs = { dir, root ? dir }: let
        imports = let
            files = readDir dir;
            p = n: v: v == "directory";
        in filterAttrs p files;

        f = n: _: let
            path = "${dir}/${n}";
        in optionalAttrs (pathExists "${path}/default.nix") {
            _name = removePrefix "${toString root}/" (toString path);
            defaults = [ path ];
        } // mkProfileAttrs {
            dir = path;
            inherit root;
        };
    in mapAttrs f imports;

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

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

        outputs = {
            # shared library functions
            lib = lib.arnix;

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

            # generate nixos templates
            nixosConfigurations = let
                inherit (self._internal) users profiles;

                system = "x86_64-linux";
                pkgs = (genPkgs root inputs).${system};

                attrs = optionalPath (root + "/templates") (p: import p {
                    lib = nixosLib { inherit inputs pkgs; };
                }) { };
            in mapAttrs' (k: v: nameValuePair "@${k}" (mkNixosSystem {
                inherit inputs pkgs system;

                config = v;
                name = "nixos";
            })) attrs;

            # Internal outputs used only for passing to other Arnix repos
            _internal = rec {
                inherit name;

                users = optionalPath (root + "/users") (p: mkProfileAttrs { dir = toString p; }) { };
                profiles = optionalPath (root + "/profiles") (p: (mkProfileAttrs { dir = toString p; })) { };

                # import the external input files
                extern = optionalPath (root + "/extern") (p: import p { inherit lib inputs; }) { };
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
        nodes ? {}, # Set of nodes to allow inter-node resolution

        name, # The hostname of the host
        bases ? [], # The base configurations for the repo
        config, # The base configuration for the host
        system ? "x86_64-linux", # Target system to build for
    }: let
        inherit (inputs) self;
        inherit (unstable.lib) nixosSystem;
        inherit (self._internal) users profiles extern overrides;
    in makeOverridable nixosSystem {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit name nodes;
            lib = nixosLib { inherit inputs pkgs; };
        };

        modules = let
            # merge down core profiles from all repos
            core.require = profiles.core.defaults;

            global = with lib.arnix.modules; [
                (globalDefaults { inherit inputs pkgs name; })
                (hmDefaults {
                    # TODO: inherit specialArgs, modules
                    specialArgs = {};
                    modules = [];
                })
            ];

            internal = { lib, ... }: with lib; {
                options.arnix = {
                    users = mkOption {
                        default = [];
                        type = types.listOf types.str;
                        description = "List of enabled user profiles, for use in conditionals.";
                    };

                    profiles = mkOption {
                        default = [];
                        type = types.listOf types.str;
                        description = "List of enabled system profiles, for use in conditionals.";
                    };
                };
            };

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
        # internal = configuration options for introspection
        # modOverrides = module overrides
        # extern.modules = modules from external flakes
        in flakeModules ++ [ core ] ++ global ++ bases ++ [
            config internal modOverrides
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

            config.require = [ hostFile ];
        };

        # make attrs for each possible host
        nodes = recImportDirs {
            dir = if flat then root else root + "/hosts";
            _import = config;
        };
    in nodes;
}