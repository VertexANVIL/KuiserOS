{ lib, inputs }: with inputs;
let
    inherit (lib) flatten;
    inherit (builtins) attrValues;

    hmModules = { };
    mkOverlay = name: pkg: (final: prev: { "${name}" = pkg; });
in
{
    modules = [
        home.nixosModules.home-manager
        impermanence.nixosModules.impermanence
    ] ++ (flatten [
        (attrValues colmena.nixosModules)
    ]);

    overlays = [
        nur.overlay

        # for packages imported from flakes
        (final: prev: {
            colmena = colmena.packages.${prev.system}.colmena;
            nixos-generators = nixos-generators.packages.${prev.system}.nixos-generators;
        })
    ];

    # passed to all nixos modules
    specialArgs = {
        inherit hmModules;

        overrideModulesPath = "${unstable}/nixos/modules";
        hardware = nixos-hardware.nixosModules;
    };
}
