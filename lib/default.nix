{ baseInputs, ... }:
let
    # Use unstable lib because some packages depend on it
    nixLib = baseInputs.xnlib.lib;
    inherit (nixLib) fix;
in fix (self: { inputs ? {}, extender ? {} }@all: let
    # construct internal lib
    lib = nixLib // {
        kuiser = self all;
    };

    f = path: import path ({
        inherit lib baseInputs;
    } // inputs);
in rec {
    importers = f ./importers.nix;
    generators = f ./generators.nix;
    modules = f ./modules.nix;

    # custom stuff
    certs = f ./certs.nix;

    # extends with a custom lib
    extend = attrs: self (all // {
        extender = extender // attrs;
    });

    extendByPath = path: extend (
        import path { inherit lib; }
    );

    # overrides with custom imports
    override = inputs: self (all // {
        inherit inputs;
    });

    inherit (importers) pkgImport;
    inherit (generators) genPkgs genPackagesOutput mkVersion mkInputStorePath
        mkColmenaHiveNodes mkRootRepo mkRepo;
    inherit (modules) systemGlobal;

    # backwards compat (stuff was moved to the xnlib flake)
    inherit (nixLib) mapFilterAttrs genAttrs' attrCount defaultAttrs defaultSetAttrs
        imapAttrsToList recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith filterListNonEmpty
        mkProfileAttrs pathsToImportedAttrs recImportFiles recImportDirs nixFilesIn
        optionalPath optionalPathImport isIPv6 tryEval'
        addrOpts addrToString addrToOpts addrsToOpts;
} // extender) {}
