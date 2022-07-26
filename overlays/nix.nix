final: prev: {
  nix_2_4 = prev.nix_2_4.overrideAttrs (o: {
    patches = [
      ../pkgs/tools/package-management/nix/0001-add-json-validate-primop.patch
      ../pkgs/tools/package-management/nix/0002-add-uri-parameter-to-validate.patch
    ];
  });
}
