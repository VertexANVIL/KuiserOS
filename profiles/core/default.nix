{ config, lib, pkgs, ... }:
{
    imports = [
        ./boot
        ./security

        # global hardware profiles
        ../hardware/common
    ];

    nix = {
        package = pkgs.nixFlakes;
        systemFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];

        autoOptimiseStore = true;
        optimise.automatic = true;

        #gc.automatic = true; # TODO: USED for arctarus, dates = daily

        extraOptions = ''
            experimental-features = nix-command flakes ca-references
            min-free = 536870912
        '';
    };

    networking.useDHCP = false;

    users = {
        mutableUsers = false;

        # this group owns /persist/nixos configuration
        groups.sysconf.gid = 600;
    };

    environment = {
        systemPackages = with pkgs; [
            # general purpose tools
            direnv htop tree jq screen rsync
            psmisc ripgrep zip unzip git

            # network tools
            nmap whois curl wget

            # disk partition tools
            cryptsetup dosfstools gptfdisk
            parted fd file ntfs3g

            # low level tools
            binutils coreutils dnsutils
            pciutils iputils moreutils
            utillinux dmidecode
        ];
    };

    programs = {
        # setcap wrappers for security hardening
        mtr.enable = true;
        traceroute.enable = true;

        # neovim as text editor
        neovim = {
            enable = true;
            viAlias = true;
            vimAlias = true;
        };
    };

    # enable recommended settings by default for nginx
    services.nginx = {
        enableReload = lib.mkDefault true;

        recommendedGzipSettings = lib.mkDefault true;
        recommendedOptimisation = lib.mkDefault true;
        recommendedProxySettings = lib.mkDefault true;
        recommendedTlsSettings = lib.mkDefault true;
    };

    hardware.enableRedistributableFirmware = true;
}
