{ config, lib, pkgs, modulesPath, ... }:
{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
    ];

    config = {
        fileSystems."/" = {
            device = "/dev/disk/by-label/nixos";
            autoResize = true;
        };

        boot = {
            growPartition = true;
            kernelParams = [ "console=tty0" ];

            loader = {
                timeout = 0;
                grub.device = "/dev/vda";
            };
        };

        services.cloud-init.enable = true;
    };
}