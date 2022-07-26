{ baseInputs, ... }:
let
  # Use unstable lib because some packages depend on it
  base = baseInputs.xnlib.lib;
  inherit (base) fix recursiveUpdate;
in
fix (self: base.extend (_: super:
let
  f = path: import path {
    lib = self;
    inherit baseInputs;
  };
in
recursiveUpdate super {
  kuiser = rec {
    importers = f ./importers.nix;
    generators = f ./generators.nix;
    modules = f ./modules.nix;

    # custom stuff
    certs = f ./certs.nix;

    inherit (importers) pkgImport;
    inherit (generators) genPkgs genPackagesOutput mkVersion mkInputStorePath mkBaseRepo mkRepo;
    inherit (modules) systemGlobal;

    # backwards compat (stuff was moved to the xnlib flake)
    inherit (base) mapFilterAttrs genAttrs' attrCount defaultAttrs defaultSetAttrs
      imapAttrsToList recursiveMerge recursiveMergeAttrsWithNames recursiveMergeAttrsWith filterListNonEmpty
      mkProfileAttrs pathsToImportedAttrs recImportFiles recImportDirs nixFilesIn
      optionalPath optionalPathImport isIPv6 tryEval'
      addrOpts addrToString addrToOpts addrsToOpts;
  };
}))
