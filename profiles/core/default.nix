{ config, lib, pkgs, ... }:
let inherit (lib) fileContents;

in
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

        #gc.automatic = true;

        extraOptions = ''
            experimental-features = nix-command flakes ca-references
            min-free = 536870912
        '';
    };

    networking.useDHCP = false;

    services = {
        gvfs.enable = true;
        fwupd.enable = true;
        earlyoom.enable = true;
    };

    users = {
        mutableUsers = false;

        # this group owns /persist/nixos configuration
        groups.sysconf.gid = 600;
    };

    environment = {
        systemPackages = with pkgs; [
            # general purpose tools
            direnv htop tree jq screen
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

            # misc libraries
            intel-sgx-sdk
        ];
    };

    # neovim as text editor
    programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
    };

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

    hardware.enableRedistributableFirmware = true;
}
