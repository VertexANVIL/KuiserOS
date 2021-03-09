{ inputs, ... }:
with inputs;
{
    modules = [];
    overlays = [];
    
    # passed to all nixos modules
    specialArgs = {
        hardware = nixos-hardware.nixosModules;
    };
}