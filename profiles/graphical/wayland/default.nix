{ pkgs, ... }:
{
    services.xserver.displayManager.gdm.wayland = true;

    xdg.portal.extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
    ];

    environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
        XDG_SESSION_TYPE = "wayland";
    };
}