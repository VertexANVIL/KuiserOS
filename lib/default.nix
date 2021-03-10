{ nixos, flake-utils, ... }:
let
    inherit (builtins) attrNames attrValues isAttrs readDir listToAttrs mapAttrs
        pathExists filter;
    
    inherit (nixos.lib) collect fold hasSuffix removePrefix removeSuffix
        nameValuePair genAttrs optionalAttrs filterAttrs hasAttr mapAttrs' mapAttrsRecursive
        recursiveUpdate nixosSystem mkForce substring optional;
    
    dummyOverlay = final: prev: {};
    optionalPathAttrs = path: expr: other: if builtins.pathExists path then expr path else other;
    
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
    
    recImport = { dir, _import ? base: import "${dir}/${base}.nix" }:
        mapFilterAttrs (_: v: v != null) (n: v:
            if n != "default.nix" && hasSuffix ".nix" n && v == "regular" then
                let name = removeSuffix ".nix" n; in nameValuePair (name) (_import name)
            else nameValuePair ("") (null)
        ) (readDir dir);
    
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = root: inputs: let
        inherit (inputs) self;
        inherit (flake-utils.lib) eachDefaultSystem;
    in (eachDefaultSystem (system:
        let
            extern = import (root + "/extern") { inherit inputs; };
            overridePkgs = pkgImport inputs.override [ ] system;
            overridesOverlay = optionalPathAttrs (root + "/overrides") (p: (import p).packages) null;

            overlays = (optional (overridesOverlay != null) (overridesOverlay overridePkgs))
            ++ [
                self.overlay
                (final: prev: {
                    # add in our sources
                    srcs = inputs.srcs.inputs;

                    # extend the "lib" namespace with arnix and flake-utils
                    lib = (prev.lib or { }) // {
                        inherit (nixos.lib) nixosSystem;
                        arnix = self.lib or inputs.arnix.lib;
                        flake-utils = flake-utils.lib;
                    };
                })
            ]
            ++ extern.overlays
            ++ self.overlays;
        in { pkgs = pkgImport nixos overlays system; }
    )).pkgs;

    # Generates the "packages" flake output
    # overlay + overlays = packages
    genPackagesOutput = root: inputs: pkgs: let
        inherit (inputs.self) overlay overlayAttrs;
        
        # grab the package names from all our overlays
        packagesNames = attrNames (overlay null null)
            ++ attrNames (fold (attr: sum: recursiveUpdate sum attr) { } (
                attrValues (mapAttrs (_: v: v null null) overlayAttrs)
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
            default = "${dir}/${n}";
        } // mkProfileAttrs "${dir}/${n}";
    in mapAttrs f imports;

    # mkProfileDefaults = profiles: let
    #     defaults = collect (x: x ? default) profiles;
    # in map (x: x.default) defaults;

    # shared repo creation function
    mkArnixRepo = root: inputs: let
        inherit (flake-utils.lib)
            eachDefaultSystem flattenTreeSystem;

        # list of module paths -> i.e. security/sgx
        moduleAttrs = paths: genAttrs' paths (path: {
            name = removePrefix "${root}/modules" (toString path);
            value = import path;
        });

        outputs = rec {
            # this represents the packages we provide
            overlay = optionalPathAttrs (root + "/pkgs") (p: import p) dummyOverlay;
            overlays = attrValues overlayAttrs;

            # imports all the overlays inside the "overlays" directory
            overlayAttrs = let
                overlayDir = root + "/overlays";
            in optionalPathAttrs overlayDir (p:
                let
                    fullPath = name: p + "/${name}";
                in pathsToImportedAttrs (
                    map fullPath (attrNames (readDir p))
                )
            ) { };

            # attrs of all our nixos modules
            nixosModules = let
                cachix = optionalPathAttrs (root + "/cachix.nix")
                    (p: { cachix = import (root + "/cachix.nix"); }) { };
                modules = optionalPathAttrs (root + "/modules/module-list.nix")
                    (p: moduleAttrs (import p)) { };
            in recursiveUpdate cachix modules;

            users = optionalPathAttrs (root + "/users") (p: mkProfileAttrs (toString p)) { };
            profiles = optionalPathAttrs (root + "/profiles") (p: (mkProfileAttrs (toString p))) { };
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
    inherit mapFilterAttrs genAttrs' pathsToImportedAttrs recImport;

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

    # Reduces profile defaults into their parent attributes
    mkProfileDefaults = profiles: (map (profile: profile.default)) profiles;

    # Produces flake outputs for the root repository
    mkRootArnixRepo = mkArnixRepo ./..;

    # Produces flake outputs for intermediate repositories
    mkIntermediateArnixRepo = root: parent: inputs: let
        repo = mkArnixRepo root inputs;
    in {
        # bring together our overlays with our parent's
        inherit (repo) overlay;
        overlays = [parent.overlay] ++ parent.overlays ++ repo.overlays;

        # merge together the attrs of our modules, profiles and users
        # this is not recursive so we will completely override our parent if required
        nixosModules = parent.nixosModules // repo.nixosModules;
        profiles = parent.profiles // repo.profiles;
        users = parent.users // repo.users;
    };

    # Produces flake outputs for the top-level repository
    mkTopLevelArnixRepo = root: parent: inputs: let
        system = "x86_64-linux";
        extern = import ./../extern { inherit inputs; };  

        # build the repository      
        repo = mkIntermediateArnixRepo root parent inputs;
        pkgs = (genPkgs root inputs).${system};
    in repo // rec {
        nixosConfigurations = import ./hosts.nix (recursiveUpdate inputs {
            inherit pkgs root system extern;
            inherit (pkgs) lib;
            inherit (inputs) arnix;
        });
    };
}