{ config, lib, pkgs, ... }:
{
    imports = [
        ./boot
        ./nix
        ./security

        # global hardware profiles
        ../hardware/common
    ];

    networking.useDHCP = false;

    hardware.enableRedistributableFirmware = true;

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

            (neovim.override {
                viAlias = true;
                vimAlias = true;
            })
        ];
    };

    programs = {
        # setcap wrappers for security hardening
        mtr.enable = true;
        traceroute.enable = true;

        # neovim as text editor
        # can't use this until 21.05
        # neovim = {
        #     enable = true;
        #     viAlias = true;
        #     vimAlias = true;
        # };
    };

    services = {
        # prefer free alternatives
        mysql.package = lib.mkOptionDefault pkgs.mariadb;

        # enable recommended settings by default for nginx
        nginx = {
            enableReload = lib.mkDefault true;

            recommendedGzipSettings = lib.mkDefault true;
            recommendedOptimisation = lib.mkDefault true;
            recommendedProxySettings = lib.mkDefault true;
            recommendedTlsSettings = lib.mkDefault true;
        };
    };
}
