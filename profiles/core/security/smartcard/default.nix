{ config, lib, pkgs, ... }:
{
    services = {
        pcscd.enable = true;
        udev.packages = with pkgs; [
            yubikey-personalization
            libu2f-host
        ];
    };

    environment.systemPackages = with pkgs; [ opensc ];
}