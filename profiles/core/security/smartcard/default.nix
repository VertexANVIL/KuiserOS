{ config, lib, pkgs, ... }:
{
    services = {
        pcscd.enable = true;
        udev.packages = with pkgs; [
            yubikey-personalization
            libu2f-host
        ];
    };

    environment.systemPackages = with pkgs; [
        opensc
        
        # TODO: move to user module;
        # these are convenience tools and GRAPHICAL
        yubikey-manager
        yubikey-manager-qt
        yubikey-personalization
        yubikey-personalization-gui
        yubioath-desktop
        yubico-piv-tool
    ];
}