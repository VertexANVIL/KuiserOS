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
}