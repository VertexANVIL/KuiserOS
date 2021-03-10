{ inputs }: with inputs;
let
    hmModules = { };
in
{
    modules = [
        home.nixosModules.home-manager
    ];

    overlays = [
        nur.overlay
    ];

    # passed to all nixos modules
    specialArgs = {
        inherit hmModules;

        overrideModulesPath = "${unstable}/nixos/modules";
        hardware = nixos-hardware.nixosModules;
    };
}
