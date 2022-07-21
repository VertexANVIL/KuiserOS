{ pkgs, ... }:
{
    services.xserver.displayManager = {
        #gdm.wayland = true;

        sessionPackages = [
            (pkgs.plasma-workspace.overrideAttrs (old: { passthru.providedSessions = [ "plasmawayland" ]; }))
        ];
    };

    xdg.portal.wlr.enable = true;

    #environment.sessionVariables = {
    #   QT_QPA_PLATFORM = "wayland";
    #};
}
