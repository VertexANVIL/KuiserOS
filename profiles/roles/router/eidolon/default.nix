{ config, pkgs, ... }:

# Base configuration for routers that are part of the Eidolon Routing Infrastructure System (RIS)
{
    boot = {
        loader.grub = {
            enable = true;
            version = 2;
        };

        kernelPackages = pkgs.linuxPackages_5_12;
    };

    networking = {
        useDHCP = false;
        nameservers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
    };

    # programs & services
    services.eidolon.enable = true;
    services.networking.fort-validator = {
        enable = true;
        acceptArinRpa = true;
    };
}