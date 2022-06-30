{ lib, baseInputs, ... }:
let
    inherit (builtins) attrNames attrValues elem readDir readFile mapAttrs pathExists;
    
    inherit (lib) fix fold flatten optionalAttrs filterAttrs genAttrs mapAttrs' mapAttrsToList splitString concatStrings
        recursiveUpdate substring optional removePrefix removeSuffix nameValuePair hasAttr hasAttrByPath attrByPath assertMsg
        genAttrs' recursiveMerge recursiveMergeAttrsWith recursiveMergeAttrsWithNames optionalPath optionalPathImport pathsToImportedAttrs recImportDirs mkProfileAttrs;
    inherit (lib.kuiser) pkgImport;
    inherit (baseInputs) nixpkgs unstable flake-utils colmena;
in rec {
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = { inputs, base ? nixpkgs }: let
        inherit (inputs) self;
        inherit (self._internal) extern overrides;
        inherit (flake-utils.lib) eachDefaultSystem;

        pkgs = (eachDefaultSystem (system:
            let
                overridePkgs = pkgImport unstable [ ] system overrides.unfree;
                overlays = (map (p: p overridePkgs) overrides.packages)
                ++ [(final: prev: {
                    # add in our sources
                    srcs = inputs.srcs.inputs;
                })]
                ++ extern.overlays
                ++ (attrValues self.overlays);
            in { pkgs = pkgImport base overlays system overrides.unfree; }
        )).pkgs;
    in pkgs;

    # Generates package sets for every possible system
    genPkgSets = inputs: let
        mkSet = base: genPkgs {
            inherit base inputs;
        };
    in {
        nixpkgs = mkSet nixpkgs;
        unstable = mkSet unstable;
    };

    # Generates the "packages" flake output
    # overlay + overlays = packages
    genPackagesOutput = inputs: pkgs: let
        inherit (inputs.self) overlays;
        
        # grab the package names from all our overlays
        packagesNames = attrNames (fold (attr: sum: recursiveUpdate sum attr) { } (
            attrValues (mapAttrs (_: v: v null null) overlays)
        ));
    in fold (key: sum: recursiveUpdate sum {
        "${key}" = pkgs.${key};
    }) { } packagesNames;

    # Creates a special library version specific to NixOS configurations
    nixosLib = { inputs, pkgs, home ? false, ... }: let
        inherit (inputs) self;

        attrs = {
            # Constructs everything we need for a profile
            mkProfile = let
                # Sources we're allowed to pull requirements from
                # (users, profiles) for nixos, (profiles) for hm
                sources = if home then {
                    inherit (self._internal.home) profiles;
                } else {
                    inherit (self._internal) users profiles;
                };
            in attrs: let
                pathToTarget = src: path: let
                    p = splitString "/" path;
                    result = attrByPath p null src;
                in
                    assert (assertMsg (result != null) "The profile \"${path}\" does not exist.");
                result;

                pathsToTarget = src: paths: map (p: pathToTarget src p) paths;
                profileDefaults = profiles: flatten ((map (p: p.defaults)) profiles);

                requires = mapAttrs (k: v:
                    pathsToTarget v (flatten (attrs.requires.${k} or []))
                ) sources;
            in (filterAttrs (n: v: n != "requires") attrs) // {
                imports = (attrs.imports or []) ++ (flatten (
                    mapAttrsToList (_: v: profileDefaults v) requires
                ));
            } // (optionalAttrs (!home) {
                # set up our configuration for introspection use
                kuiser = {
                    users = map (p: p._name) requires.users;
                    profiles = map (p: p._name) requires.profiles;
                };
            });
        };
    in lib.extend (self: super: {
        kuiser = super.kuiser // attrs;
    });

    # extend the `lib` namespace with home-manager's `hm`
    nixosLibHm = { inputs, pkgs }: let
        lib = nixosLib { inherit inputs pkgs; home = true; };
    in import (inputs.home + "/modules/lib/stdlib-extended.nix") lib;

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

    # Retrieves the store path of one of our base inputs
    mkInputStorePath = input: baseInputs.${input}.outPath;

    # shared repo creation function
    mkBaseRepo = all@{ inputs, _root ? null, ... }: let
        inherit (flake-utils.lib)
            eachDefaultSystem flattenTreeSystem;
        inherit (inputs) self;
        pkgSets = genPkgSets inputs;

        root = if _root == null then self.outPath else _root;

        # list of module paths -> i.e. security/sgx
        # too bad we cannot output actual recursive attribute sets :(
        moduleAttrs = paths: genAttrs' paths (path: {
            name = removePrefix "${root}/modules/" (toString path);
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
            inherit lib;

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
                pkgs = pkgSets.nixpkgs.${system};

                attrs = optionalPath (root + "/templates") (p: import p {
                    lib = nixosLib { inherit inputs pkgs; };
                }) { };
            in mapAttrs' (k: v: nameValuePair "@${k}" (mkNixosSystem {
                inherit inputs system pkgSets;

                config = v;
                name = "nixos";
            })) attrs;

            # Internal outputs used only for passing to other KuiserOS repos
            _internal = rec {
                roots = [ root ];
                users = optionalPath (root + "/users") (p: mkProfileAttrs { dir = toString p; }) { };
                profiles = optionalPath (root + "/profiles") (p: (mkProfileAttrs { dir = toString p; })) { };

                home = {
                    modules = optionalPath (root + "/users/modules/module-list.nix") (p: moduleAttrs (import p)) { };
                    profiles = optionalPath (root + "/users/profiles") (p: mkProfileAttrs { dir = toString p; }) { };
                };

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
            mkEachSystem = f: eachDefaultSystem (system: f system pkgSets.nixpkgs.${system});
        in (mkEachSystem (system: pkgs: {
            devShell = let
                # current repo's working dir is added; parent repos are added as store paths
                allRoots = map (i: if i == root then "$(pwd)" else i) self._internal.roots;
                shellAttrs = self._internal.shell.${system};
            in pkgs.mkShell (shellAttrs // {
                shellHook = ''
                    # merge down the path / pythonpath
                    export PATH="$PATH${concatStrings (map (r: ":${r}/bin") allRoots)}"
                    export PYTHONPATH="$PYTHONPATH${concatStrings (map (r: ":${r}/lib/python") allRoots)}"

                    # set our PS1 line
                    export PS1_PREFIX='\[\033[35m\][operator shell]\[\033[0m\]'
                    export PS1_PROMPT='\[\033[32m\]\w\[\033[0m\]> '
                    export PS1="$PS1_PREFIX $PS1_PROMPT"
                '' + (if hasAttr "shellHook" shellAttrs then shellAttrs.shellHook else "");
            });

            packages = flattenTreeSystem system (genPackagesOutput inputs pkgs);
        })) // {
            _internal = mkEachSystem (system: pkgs: {
                # this lets children add stuff to the shell
                shell = optionalPath (root + "/shell") (p: import p { inherit pkgs root; }) {};
            });
        };
    in recursiveUpdate outputs systemOutputs;

    # Produces flake outputs for repositories
    mkRepo = {
        name,
        parent,
        inputs,
        flat ? false,
        system ? "x86_64-linux",

        _root ? null
    }@all: let
        inherit (inputs) self;
        root = if _root == null then self.outPath else _root;
        pkgSets = genPkgSets inputs;

        # build the repository
        repo = let
            local = mkBaseRepo (all // { inputs = baseInputs // inputs; _root = root; });

            # merge together the attrs we need from our parent
            shallowMerged = recursiveMergeAttrsWithNames
                ["nixosModules" "overlays" "packages"] (a: b: a // b) [ parent local ];
            deepMerged = recursiveMergeAttrsWithNames
                ["lib" "_internal"] (a: b: recursiveMerge [ a b ]) [ parent local ];
        in (shallowMerged // deepMerged) // {
            inherit (local) devShell;
        };

        # function to create our host attrs
        hostOutputs = let
            inherit (nixpkgs.lib) nixosSystem;

            hosts = mkHosts {
                inherit root flat;
            };

            common = {
                inherit root hosts system pkgSets;
                inputs = baseInputs // inputs;
            };

            nixosSystems = mkNixosSystems common;
        in rec {
            nixosConfigurations = mapAttrs (_: nixosSystem) nixosSystems;
            homeConfigurations = mkHomes common;

            colmena = let
                pkgs = pkgSets.nixpkgs.${system};
            in (mapAttrs (_: v: {
                imports = v.modules;
                nixpkgs.system = v.system;
            }) nixosSystems) // {
                meta = {
                    nixpkgs = pkgs;
                    specialArgs = mkColmenaSpecialArgs common;
                };
            };
        };
    in recursiveUpdate repo hostOutputs;

    mkColmenaSpecialArgs = {
        inputs,
        pkgSets,
        system,
        ...
    }: let
        inherit (inputs) self;
        inherit (self._internal) extern;

        pkgs = pkgSets.nixpkgs.${system};
        unstable = pkgSets.unstable.${system};
    in extern.specialArgs // {
        inherit unstable;
        lib = nixosLib { inherit inputs pkgs; };
    };

    # Builds a NixOS system
    mkNixosSystem = {
        inputs, # The flake inputs
        nodes ? {}, # Set of nodes to allow inter-node resolution

        name, # The hostname of the host
        config, # The base configuration for the host
        system, # Target system to build for
        pkgSets, # The compiled package sets
    }: let
        inherit (inputs) self;
        inherit (self._internal) extern home overrides profiles users;

        pkgs = pkgSets.nixpkgs.${system};
        unstable = pkgSets.unstable.${system};
    in {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit name nodes unstable;
            lib = nixosLib { inherit inputs pkgs; };

            # temporary hack until we figure out what is breaking this (?)
            host = name;
        };

        modules = let
            # merge down core profiles from all repos
            core.require = profiles.core.defaults;

            global = with lib.kuiser.modules; [
                (globalDefaults { inherit inputs pkgs name; })
                (hmDefaults {
                    sharedModules = extern.home.modules ++ (attrValues home.modules);
                    extraSpecialArgs = let
                        lib = nixosLibHm { inherit inputs pkgs; };
                    in extern.home.specialArgs // {
                        # add our unstable package set
                        inherit lib unstable;
                        host = name;
                    };
                })
            ];

            internal = { lib, ... }: with lib; {
                options.kuiser = {
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
        # config = the actual host configuration
        # internal = configuration options for introspection
        # modOverrides = module overrides
        # extern.modules = modules from external flakes
        in flakeModules ++ [ core ] ++ global ++ [
            config internal modOverrides
        ] ++ extern.modules;

        extraModules = [
            colmena.nixosModules.deploymentOptions
        ];
    };

    # Imports an attribute set of hosts from a folder
    mkHosts = { root, flat }: recImportDirs {
        dir = if flat then root else root + "/hosts";
        _import = name: root + (if flat then "/${name}" else "/hosts/${name}");
    };

    # Builds a set of NixOS systems from given hosts
    mkNixosSystems = {
        inputs,
        root,
        hosts,

        system ? "x86_64-linux", # Target system to build for
        pkgSets
    }: let
        nodes = mapAttrs (name: file: mkNixosSystem {
            inherit inputs name nodes system pkgSets;
            config.require = [ file ];
        }) hosts;
    in nodes;

    # Builds a set of Home Manager configurations from the users folder for each host
    mkHomes = {
        inputs,
        root,
        hosts,

        system ? "x86_64-linux", # Target system to build for
        flat ? false,
        pkgSets
    }: let
        inherit (inputs) self;
        inherit (self._internal) extern home;
        inherit (inputs.home.lib) homeManagerConfiguration;

        pkgs = pkgSets.nixpkgs.${system};

        config = host: username: let
        in homeManagerConfiguration {
            inherit pkgs system username;
            homeDirectory = "/home/${username}";

            # TODO: deduplicate these?
            extraModules = extern.home.modules ++ (attrValues home.modules);
            extraSpecialArgs = extern.home.specialArgs // {
                inherit host;

                # add our unstable package set
                unstable = pkgSets.unstable.${system};
                lib = nixosLibHm { inherit inputs pkgs; };
            };

            configuration = {
                imports = [(root + "/users/${username}/home.nix")];
            };
        };
    in recursiveMerge (mapAttrsToList (host: _: recImportDirs {
        dir = root + "/users";
        nameModifier = n: "${n}@${host}";
        _import = config host;
    }) hosts);
}
