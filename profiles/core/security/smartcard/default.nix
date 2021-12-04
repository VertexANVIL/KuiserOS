{ config, lib, pkgs, ... }:
{
    services = {
        pcscd = {
            enable = true;
            plugins = with pkgs; [ ccid acsccid ];
        };

        udev.packages = with pkgs; [
            yubikey-personalization
            libu2f-host
        ];
    };

    environment.systemPackages = with pkgs; [ opensc ];
}