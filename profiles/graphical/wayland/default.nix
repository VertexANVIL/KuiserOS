{ pkgs, ... }:
{
    services.pipewire.enable = true;
    services.xserver.displayManager.gdm.wayland = true;

    xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
            xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk
        ];

        gtkUsePortal = true;
    };

    environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
        XDG_SESSION_TYPE = "wayland";
    };
}