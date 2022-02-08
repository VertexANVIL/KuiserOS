{ config, lib, pkgs, ... }:
{
    services = {
        pcscd = {
            enable = true;
            plugins = with pkgs; [ ccid acsccid pcsc-cyberjack ];
        };

        udev.packages = with pkgs; [
            yubikey-personalization
            libu2f-host
        ];
    };

    environment.systemPackages = with pkgs; [ opensc ];
}