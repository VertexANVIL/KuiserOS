{ baseInputs, ... }:
let
    inherit (baseInputs.unstable) lib;
    inherit (lib) fix;
in fix (self: { inputs ? {} }: let
    f = path: import path ({
        # construct internal lib
        lib = lib // {
            arnix = self {};
            override = inputs: self {
                inherit inputs;
            };
        };

        inherit baseInputs;
    } // inputs);
in rec {
    attrs = f ./attrs.nix;
    lists = f ./lists.nix;
    importers = f ./importers.nix;
    generators = f ./generators.nix;
    misc = f ./misc.nix;
    modules = f ./modules.nix;

    # custom stuff
    ansi = f ./ansi.nix;
    certs = f ./certs.nix;
    systemd = f ./systemd.nix;

    inherit (attrs) mapFilterAttrs genAttrs' attrCount defaultSetAttrs
        imapAttrsToList recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith;
    inherit (lists) filterListNonEmpty;
    inherit (importers) pkgImport pathsToImportedAttrs recImportFiles recImportDirs nixFilesIn;
    inherit (generators) genPkgs genPackagesOutput mkProfileAttrs mkVersion mkProf mkInputStorePath
        mkColmenaHiveNodes mkRootArnixRepo mkArnixRepo;
    inherit (misc) optionalPath optionalPathImport isIPv6;
}) {}
