{ pkgs, ... }:
{
    services = {
        # for network discovery
        avahi = {
            enable = true;
            nssmdns = true;
        };

        gvfs.enable = true;
        fwupd.enable = true;
        udisks2.enable = true;
        earlyoom.enable = true;
    };

    networking.networkmanager = {
        enable = true;

        # stable randomised MAC address that resets at boot
        # wifi.macAddress = "stable";
        # ethernet.macAddress = "stable";

        # extraConfig = ''
        #     [connection]
        #     connection.stable-id=''${CONNECTION}/''${BOOT}
        # '';
    };

    # add our custom fonts
    fonts = {
        fonts = with pkgs; [
            noto-fonts
            (nerdfonts.override { fonts = [
                "FiraCode"
                "FiraMono"
            ]; })
        ];

        fontconfig.defaultFonts = {
            monospace = [ "FiraMono Nerd Font" ];
            sansSerif = [ "Noto Sans" ];
            serif = [ "Noto Serif" ];
        };
    };

    programs = {
        # start SSH agent
        ssh.startAgent = true;

        # fish is actually configured inside home-manager;
        # however we need to enable it here so it gets put in /etc/shells
        fish.enable = true;

        # binary wrapper config is elsewhere
        firejail.enable = true;
    };
}