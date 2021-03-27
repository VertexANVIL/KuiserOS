{ inputs }: with inputs;
let
    hmModules = { };
    mkOverlay = name: pkg: (final: prev: { "${name}" = pkg; });
in
{
    modules = [
        home.nixosModules.home-manager
        impermanence.nixosModules.impermanence
    ];

    overlays = [
        nur.overlay

        # for packages imported from flakes
        (final: prev: { deploy-rs = deploy.packages.${prev.system}.deploy-rs; })
    ];

    # passed to all nixos modules
    specialArgs = {
        inherit hmModules;

        overrideModulesPath = "${unstable}/nixos/modules";
        hardware = nixos-hardware.nixosModules;
    };
}
