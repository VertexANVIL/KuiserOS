{ nixos, ... }:
let
    inherit (builtins) attrNames attrValues isAttrs readDir listToAttrs mapAttrs
        pathExists filter;
    
    inherit (nixos.lib) fold filterAttrs hasSuffix mapAttrs' nameValuePair removeSuffix
        recursiveUpdate genAttrs nixosSystem mkForce substring optionalAttrs;
    
    # mapFilterAttrs ::
    #   (name -> value -> bool )
    #   (name -> value -> { name = any; value = any; })
    #   attrs
    mapFilterAttrs = seive: f: attrs: filterAttrs seive (mapAttrs' f attrs);

    # Generate an attribute set by mapping a function over a list of values.
    genAttrs' = values: f: listToAttrs (map f values);

    # pkgImport :: Nixpkgs -> Overlays -> System -> Pkgs
    pkgImport = nixpkgs: overlays: system: import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
    };

    # Convert a list to file paths to attribute set
    # that has the filenames stripped of nix extension as keys
    # and imported content of the file as value.
    pathsToImportedAttrs = paths: let
        paths' = filter (hasSuffix ".nix") paths;
    in
        genAttrs' paths' (path: {
            name = removeSuffix ".nix" (baseNameOf path);
            value = import path;
        });
    
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = root: inputs: let
        inherit (inputs) self;
        inherit (inputs.flake-utils.lib) eachDefaultSystem;
    in (eachDefaultSystem (system:
        let
            extern = import (root + "/extern") { inherit inputs; };
            overridePkgs = pkgImport inputs.override [ ] system;
            overridesOverlay = (import (root + "/overrides")).packages;

            overlays = [
                (overridesOverlay overridePkgs)
                self.overlay
                (final: prev: {
                    # add in our sources
                    srcs = inputs.srcs.inputs;

                    # extend the "lib" namespace
                    lib = (prev.lib or { }) // {
                        inherit (nixos.lib) nixosSystem;
                        flk = self.lib;
                        flake-utils = inputs.flake-utils.lib;
                    };
                })
            ]
            ++ extern.overlays
            ++ (attrValues self.overlays);
        in { pkgs = pkgImport nixos overlays system; }
    )).pkgs;

    # Generates the "packages" flake output
    # overlay + overlays = packages
    genPackagesOutput = root: inputs: pkgs: let
        inherit (inputs.self) overlay overlays;
        
        # grab the package names from all our overlays
        packagesNames = attrNames (overlay null null)
            ++ attrNames (fold (attr: sum: recursiveUpdate sum attr) { } (
                attrValues (mapAttrs (_: v: v null null) overlays)
            ));
    in fold (key: sum: recursiveUpdate sum {
        "${key}" = pkgs.${key};
    }) { } packagesNames;

    # shared repo creation function
    mkArnixRepo = root: inputs: let
        inherit (inputs.flake-utils.lib)
            eachDefaultSystem flattenTreeSystem;

        outputs = {
            # this represents the packages we provide
            overlay = import (root + "/pkgs");

            # imports all the overlays inside the "overlays" directory
            overlays = let
                overlayDir = root + "/overlays";
                fullPath = name: overlayDir + "/${name}";
            in pathsToImportedAttrs (
                map fullPath (attrNames (readDir overlayDir))
            );

            # attrs of all our nixos modules
            nixosModules = let
                cachix = { cachix = import (root + "/cachix.nix"); };
                modules = pathsToImportedAttrs (import (root + "/modules/module-list.nix"));
            in recursiveUpdate cachix modules;
        };

        # Generate per-system outputs
        # i.e. x86_64-linux, aarch64-linux
        systemOutputs = eachDefaultSystem (system: let
            pkgs = (genPkgs root inputs).${system};
        in {
            packages = flattenTreeSystem system (genPackagesOutput root inputs pkgs);

            # WTF is this shit supposed to do?
            #legacyPackages.hmActivationPackages =
            #    genHomeActivationPackages { inherit self; };
        });
    in recursiveUpdate outputs systemOutputs;
in rec {
    # setup is as follows:
    # personal repo -> this repo
    # colmena hives -> arctarus repo -> this repo

    # all repos are merged together to produce a
    # resultant set of modules, profiles, packages, users, and library functions
    # hosts are configured at the top level only
    inherit mapFilterAttrs genAttrs' pkgImport pathsToImportedAttrs;

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

    # Produces flake outputs for the root repository
    mkRootArnixRepo = mkArnixRepo ./..;

    # Produces flake outputs for intermediate repositories
    mkIntermediateArnixRepo = root: parent: inputs: let
        repo = mkArnixRepo root;
    in {
        overlays = parent.overlays ++ repo.overlays;
        nixosModules = recursiveUpdate parent.nixosModules repo.nixosModules;
    };

    # Produces flake outputs for the top-level repository
    mkTopLevelArnixRepo = root: parent: inputs: let
        system = "x86_64-linux";
        extern = import ./extern { inherit inputs; };  

        # build the repository      
        repo = mkIntermediateArnixRepo root parent inputs;
        inherit (repo) pkgs;
    in repo // {
        nixosConfigurations = import (root + "/hosts") (recursiveUpdate inputs {
            inherit pkgs system extern;
            inherit (pkgs) lib;
        });
    };
}