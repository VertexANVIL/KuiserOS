{ baseInputs, ... }:
let
    # Use unstable lib because some packages depend on it
    base = baseInputs.xnlib.lib;
    inherit (base) mkExtensibleLibrary;
in mkExtensibleLibrary base ({ self, importer }: let
    f = importer {
        inherit baseInputs;
    };
in {
    kuiser = rec {
        importers = f ./importers.nix;
        generators = f ./generators.nix;
        modules = f ./modules.nix;

        # custom stuff
        certs = f ./certs.nix;

        inherit (importers) pkgImport;
        inherit (generators) genPkgs genPackagesOutput mkVersion mkInputStorePath
            mkColmenaHiveNodes mkRootRepo mkRepo;
        inherit (modules) systemGlobal;

        # backwards compat (stuff was moved to the xnlib flake)
        inherit (base) mapFilterAttrs genAttrs' attrCount defaultAttrs defaultSetAttrs
            imapAttrsToList recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith filterListNonEmpty
            mkProfileAttrs pathsToImportedAttrs recImportFiles recImportDirs nixFilesIn
            optionalPath optionalPathImport isIPv6 tryEval'
            addrOpts addrToString addrToOpts addrsToOpts;
    };
})
