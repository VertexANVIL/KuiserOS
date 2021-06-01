{ ... }:
{
    # enable gdm and gnome
    services.xserver = {
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
    };

    services.gnome.chrome-gnome-shell.enable = true;
}