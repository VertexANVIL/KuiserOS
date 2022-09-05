{ lib, ... }:
let
  inherit (lib) mkDefault;
in
{
  # Default dynamically generated NixOS configuration for all hosts
  globalDefaults = { inputs, pkgs, name }:
    { config, ... }:
    let
      inherit (inputs) self home nixos unstable;
    in
    {
      nix.nixPath = [
        "nixpkgs=${nixos}"
        "unstable=${unstable}"
        "nixos-config=${self}/compat/nixos"
        "home-manager=${home}"
      ];

      nix.registry = {
        kuiser.flake = self;
        nixos.flake = nixos;
        unstable.flake = unstable;
      };

      # set up system hostname
      networking.hostName = mkDefault name;
      deployment.targetHost = with config; mkDefault "${networking.hostName}.${networking.domain}";

      # always enable firmware by defaukt
      hardware.enableRedistributableFirmware = mkDefault true;

      # use flake revision
      system.configurationRevision = lib.mkIf (self ? rev) self.rev;

      # TODO: doesn't go here?
      nixpkgs = { inherit pkgs; };
    };

  # Default home-manager configuration
  hmDefaults = { sharedModules, extraSpecialArgs }: {
    config = {
      home-manager = {
        inherit sharedModules extraSpecialArgs;

        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  };

  # Packages and etc that's global to a system
  # Shared on both NixOS and home-manager
  systemGlobal = { pkgs }: {
    packages = with pkgs; [
      # general purpose tools
      direnv
      tree
      jq
      screen
      skim
      rsync
      ripgrep
      zip
      unzip
      git
      pwgen
      openssl

      # network tools
      nmap
      whois
      curl
      wget

      # process tools
      htop
      psmisc

      # disk partition tools
      cryptsetup
      dosfstools
      gptfdisk
      parted
      fd
      file
      ntfs3g

      # hardware tools
      usbutils
      pciutils
      lshw
      hwinfo
      dmidecode

      # nix tools
      nix-index
      nixos-option

      # others
      binutils
      coreutils
      dnsutils
      iputils
      moreutils
      utillinux
    ];

    # set up general pager options
    variables = rec {
      PAGER = "less -R";
      LESS = "-iFJMRW -x4";
      LESSOPEN = "|${pkgs.lesspipe}/bin/lesspipe.sh %s";
      SYSTEMD_LESS = LESS;

      # Vault Production Hardening:
      # hide vault commands by default
      HISTIGNORE = "&:vault*";
    };

    aliases = {
      # fix nixos-option
      nixos-option = "nixos-option -I nixpkgs=${toString ../../compat}";
    };
  };
}
