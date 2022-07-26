{ lib, inputs }:
let
  inherit (lib) flatten genAttrs;
  inherit (builtins) attrValues;

  hmModules = { };
  mkOverlay = name: pkg: (final: prev: { "${name}" = pkg; });
in
{
  modules = with inputs; [
    home.nixosModules.home-manager
    impermanence.nixosModules.impermanence
  ] ++ (flatten [
    # nothing here yet...
  ]);

  overlays = with inputs; [
    nur.overlay

    # for packages imported from flakes
    (final: prev:
      let
        importNamed = names: genAttrs names (n:
          inputs.${n}.packages.${prev.system}.${n}
        );
      in
      (importNamed [
        "nixos-generators"
      ]))
  ];

  # passed to all nixos modules
  specialArgs = {
    overrideModulesPath = "${inputs.unstable}/nixos/modules";
    hardware = inputs.nixos-hardware.nixosModules;
  };

  # added to home-manager
  # equivalent to modules and specialArgs
  home = {
    modules = [ ];
    specialArgs = { };
  };
}
