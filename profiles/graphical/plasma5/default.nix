{ ... }:
{
    # enable Plasma5
    services.xserver = {
        displayManager.sddm.enable = true;

        desktopManager.plasma5 = {
            enable = true;
            supportDDC = true;
        };
    };

    # open ports for KDE Connect
    networking.firewall = {
        allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
        allowedUDPPortRanges = [{ from = 1714; to = 1764; }];
    };
}