{ ... }:
{
    # enable gdm and gnome3
    services.xserver = {
        displayManager.gdm.enable = true;
        desktopManager.gnome3.enable = true;
    };

    services.gnome3.chrome-gnome-shell.enable = true;
}