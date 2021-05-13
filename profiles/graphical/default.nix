{ pkgs, ... }:
{
    sound.enable = true;
    console.useXkbConfig = true;

    hardware = {
        opengl = {
            enable = true;
            driSupport = true;
            extraPackages = with pkgs; [
                libvdpau-va-gl
                intel-media-driver
                vaapiIntel vaapiVdpau
            ];
        };

        pulseaudio = {
            enable = true;
            support32Bit = true; # Steam, etc
            package = pkgs.pulseaudioFull;
        };
    };

    services = {
        xserver = {
            enable = true;
            wacom.enable = true;
            libinput.enable = true;
        };

        gnome3.chrome-gnome-shell.enable = true;

        # Use graphical usbguard package
        usbguard.package = pkgs.usbguard;
    };

    security.chromiumSuidSandbox.enable = true;

    environment.systemPackages = with pkgs; [
        playerctl pavucontrol alsaTools
        modem-manager-gui
    ];

    programs = {
        dconf.enable = true;
        usbtop.enable = true;
    };
}
