{ pkgs, ... }:
{
    services.xserver.displayManager = {
        sddm.settings.Wayland.SessionDir = "${pkgs.plasma5Packages.plasma-workspace}/share/wayland-sessions";
        #gdm.wayland = true;
    };

    xdg.portal.wlr.enable = true;

    #environment.sessionVariables = {
    #   QT_QPA_PLATFORM = "wayland";
    #};
}
