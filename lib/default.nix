{ baseInputs, ... }:
let
    # Use unstable lib because some packages depend on it
    nixLib = baseInputs.nixpkgs.lib;
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
    attrs = f ./attrs.nix;
    lists = f ./lists.nix;
    importers = f ./importers.nix;
    generators = f ./generators.nix;
    misc = f ./misc.nix;
    modules = f ./modules.nix;
    strings = f ./strings.nix;

    # custom stuff
    objects = {
        addrs = f ./objects/addrs.nix;
    };

    ansi = f ./ansi.nix;
    certs = f ./certs.nix;
    systemd = f ./systemd.nix;

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

    inherit (attrs) mapFilterAttrs genAttrs' attrCount defaultAttrs defaultSetAttrs
        imapAttrsToList recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith;
    inherit (lists) filterListNonEmpty;
    inherit (importers) pkgImport pathsToImportedAttrs recImportFiles recImportDirs nixFilesIn;
    inherit (generators) genPkgs genPackagesOutput mkProfileAttrs mkVersion mkInputStorePath
        mkColmenaHiveNodes mkRootRepo mkRepo;
    inherit (misc) optionalPath optionalPathImport isIPv6 tryEval';
    inherit (modules) systemGlobal;

    inherit (objects.addrs) addrOpts addrToString addrToOpts addrsToOpts;
} // extender) {}
