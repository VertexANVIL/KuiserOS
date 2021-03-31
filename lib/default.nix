{ nixos, flake-utils, baseInputs, ... }:
let
    inherit (builtins) attrNames attrValues isAttrs readDir isList
        elem listToAttrs hasAttr mapAttrs pathExists filter parseDrvName;
    
    inherit (nixos.lib) all collect fold flatten head tail last unique length hasSuffix removePrefix removeSuffix nameValuePair
        genList genAttrs optionalAttrs filterAttrs mapAttrs' mapAttrsToList setAttrByPath
        zipAttrsWith zipAttrsWithNames recursiveUpdate nixosSystem mkForce concatLists concatMap
        substring remove optional foldl' elemAt traceVal traceSeq traceSeqN;
    
    # imports all our dependent libraries
    libImports = let
        gen = v: zipAttrsWith (name: vs: foldl' (a: b: a // b) {} vs) v;
    in gen [ ];

    # if path exists, evaluate expr with it, otherwise return other
    optionalPath = path: expr: other: if builtins.pathExists path then expr path else other;

    # if path exists, import it, otherwise return other
    optionalPathImport = path: other: optionalPath path (p: import p) other;
    
    # mapFilterAttrs ::
    #   (name -> value -> bool )
    #   (name -> value -> { name = any; value = any; })
    #   attrs
    mapFilterAttrs = seive: f: attrs: filterAttrs seive (mapAttrs' f attrs);

    # Generate an attribute set by mapping a function over a list of values.
    genAttrs' = values: f: listToAttrs (map f values);

    # pkgImport :: Nixpkgs -> Overlays -> System -> Unfree -> Pkgs
    pkgImport = nixpkgs: overlays: system: unfree: import nixpkgs {
        inherit system overlays;
        
        # predicate for unfree packages
        config.allowUnfreePredicate = pkg:
            elem (pkg.pname or (parseDrvName pkg.name).name) unfree;
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
    
    recImportFiles = { dir, _import }:
        mapFilterAttrs (_: v: v != null) (n: v:
            if n != "default.nix" && hasSuffix ".nix" n && v == "regular" then
                let name = removeSuffix ".nix" n; in nameValuePair (name) (_import name)
            else nameValuePair ("") (null)
        ) (readDir dir);
    
    recImportDirs = { dir, _import }:
        mapFilterAttrs (_: v: v != null) (n: v:
            if v == "directory" then nameValuePair n (_import n)
            else nameValuePair ("") (null)
        ) (readDir dir);
    
    # Recursively merges attribute sets **and** lists
    recursiveMerge = attrList: let f = attrPath: zipAttrsWith (n: values:
        if tail values == [] then head values
        else if all isList values then unique (concatLists values)
        else if all isAttrs values then f [n] values
        else last values
    ); in f [] attrList;

    recursiveMergeAttrsWithNames = names: f: sets:
        zipAttrsWithNames names (name: vs: builtins.foldl' f { } vs) sets;

    recursiveMergeAttrsWith = f: sets:
        recursiveMergeAttrsWithNames (concatMap attrNames sets) f sets;
    
    # Generates packages for every possible system
    # extern + overlay => { foobar.x86_64-linux }
    genPkgs = root: inputs: let
        inherit (inputs) self;
        inherit (self._internal) extern overrides;
        inherit (flake-utils.lib) eachDefaultSystem;
    in (eachDefaultSystem (system:
        let
            overridePkgs = pkgImport baseInputs.unstable [ ] system overrides.unfree;
            overlays = (map (p: p overridePkgs) overrides.packages)
            ++ [(final: prev: {
                    # add in our sources
                    srcs = inputs.srcs.inputs;

                    # extend the "lib" namespace with arnix and flake-utils
                    lib = (prev.lib or { }) // {
                        inherit (nixos.lib) nixosSystem;
                        arnix = self.lib or inputs.arnix.lib;
                        flake-utils = flake-utils.lib;
                    };
            })]
            ++ extern.overlays
            ++ (attrValues self.overlays);
        in { pkgs = pkgImport nixos overlays system overrides.unfree; }
    )).pkgs;

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
    
    genAttrsFromPaths = paths: recursiveMergeAttrsWith (a: b: a // b) (map (p: setAttrByPath p.name p.value) paths);

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

    # shared repo creation function
    mkArnixRepo = all@{ name, root, inputs, ... }: let
        inherit (flake-utils.lib)
            eachDefaultSystem flattenTreeSystem;

        # list of module paths -> i.e. security/sgx
        # too bad we cannot output actual recursive attribute sets :(
        moduleAttrs = paths: genAttrs' paths (path: {
            name = removePrefix "${toString (root + "/modules")}/" (toString path);
            value = import path;
        });

        overlay = optionalPathImport (root + "/pkgs") (final: prev: {});

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
        systemOutputs = eachDefaultSystem (system: let
            pkgs = (genPkgs root inputs).${system};
            
        in {
            packages = flattenTreeSystem system (genPackagesOutput root inputs pkgs);

            # for `nix develop`
            devShell = optionalPath (root + "/shell.nix") (p: import p { inherit pkgs; }) (pkgs.mkShell {});

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
    inherit mapFilterAttrs genAttrs' pathsToImportedAttrs recImportFiles recImportDirs
        recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith;

    systemd = import ./systemd.nix;

    # counts the number of attributes in a set
    attrCount = set: length (attrNames set);

    # given a list of attribute sets, merges the keys specified by "names" from "defaults" into them if they do not exist
    defaultSetAttrs = sets: names: defaults: (mapAttrs' (n: v: nameValuePair n (
        v // genAttrs names (name: (if hasAttr name v then v.${name} else defaults.${name}) )
    )) sets);

    # maps attrs to list with an extra i iteration parameter
    imapAttrsToList = f: set: (
    let
        keys = attrNames set;
    in
    genList (n:
        let
            key = elemAt keys n;
            value = set.${key};
        in 
        f n key value
    ) (length keys));

    # determines whether a given address is IPv6 or not
    isIPv6 = str: builtins.match ".*:.*" str != null;

    # filters out empty strings and null objects from a list
    filterListNonEmpty = l: (filter (x: (x != "" && x != null)) l);

    # converts nix files in directory to name/value pairs
    nixFilesIn = dir: mapAttrs' (name: value: nameValuePair (removeSuffix ".nix" name) (import (dir + "/${name}")))
        (filterAttrs (name: _: hasSuffix ".nix" name)
        (builtins.readDir dir));

    # if condition, then return the value, else an empty list
    optionalList = cond: val: if cond then val else [];

    # Constructs a semantic version string from a derivation
    mkVersion = src: "${substring 0 8 src.lastModifiedDate}_${src.shortRev}";

    # Reduces profile defaults into their parent attributes
    mkProf = profiles: flatten ((map (profile: profile.defaults)) profiles);

    # Produces flake outputs for the root repository
    mkRootArnixRepo = all@{ inputs, ... }: mkArnixRepo (all // {
        name = "root";
        root = ./..;
    });

    # Produces flake outputs for intermediate repositories
    mkIntermediateArnixRepo = all@{ name, root, parent, inputs, ... }: let
        repo = mkArnixRepo (all // { inputs = baseInputs // inputs; });

        # merge together the attrs we need from our parent
        merged1 = recursiveMergeAttrsWithNames
            ["nixosModules" "overlays" "packages"] (a: b: a // b) [ parent repo ];
        merged2 = recursiveMergeAttrsWithNames
            ["lib" "_internal"] (a: b: recursiveMerge [ a b ]) [ parent repo ];
        both = merged1 // merged2;
    in both // {
        inherit (repo) devShell;
    };

    # Produces flake outputs for the top-level repository
    mkTopLevelArnixRepo = all@{ root, parent, inputs, base ? { }, flat ? false, ... }: let
        inherit (baseInputs) deploy colmena;
        inherit (inputs) self;
        system = "x86_64-linux";

        inherit (colmena.lib.${system}) mkColmenaHive;

        # build the repository
        repo = mkIntermediateArnixRepo (all // { name = "toplevel"; });
        pkgs = (genPkgs root inputs).${system};
    in repo // {
        nixosConfigurations = import ./hosts.nix {
            inherit pkgs root system base flat;
            inherit (pkgs) lib;
            inherit (repo._internal) extern;
            inputs = baseInputs // inputs;
        };

        colmena = mkColmenaHive {
            inherit system;
            nodes = self.nixosConfigurations;
        };

        # add checks for deploy-rs
        # checks = mapAttrs (system: deployLib:
        #     deployLib.deployChecks self.deploy
        # ) deploy.lib;
    };
} // libImports
