{ config, lib, pkgs, ... }:
{
    imports = [
        ./nfs-fixes.nix
    ];

    services = {
        # for network discovery
        avahi = {
            enable = true;
            nssmdns = true;
            publish = {
                enable = true;
                addresses = true;
            };
        };

        # NFS shares
        nfs.server = {
            enable = true;

            statdPort = 4000;
            lockdPort = 4001;
            mountdPort = 4002;

            # udp by default
            extraNfsdConfig = ''
                udp=y
            '';
        };

        gvfs.enable = true;
        fwupd.enable = true;
        udisks2.enable = true;
        earlyoom.enable = true;
    };

    security = {
        # revert back to sudo, as we need it for development stuff
        sudo.enable = true;
        doas.enable = false;
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