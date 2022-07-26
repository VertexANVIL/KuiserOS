{ lib, ... }:
let
  inherit (builtins) elem parseDrvName;
in
rec {
  # pkgImport :: Nixpkgs -> Overlays -> System -> Unfree -> Pkgs
  pkgImport = nixpkgs: overlays: system: unfree: import nixpkgs {
    inherit system overlays;

    # predicate for unfree packages
    config.allowUnfreePredicate = pkg:
      elem (pkg.pname or (parseDrvName pkg.name).name) unfree;
  };
}
