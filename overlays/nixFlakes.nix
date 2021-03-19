final: prev: {
    nixFlakes = prev.nixFlakes.overrideAttrs (self: {
        patches = (self.patches or []) ++ [
            # Makes "follows" statements in flakes relative to the current flake, no matter what
            ../pkgs/tools/package-management/nix/0001-relative-input-follows.patch

            # Makes warnings respect verbosity
            ../pkgs/tools/package-management/nix/0002-fix-warning-verbosity.patch
        ];
    });
}