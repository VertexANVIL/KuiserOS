{ config, lib, pkgs, ... }:
let
  inherit (lib.kuiser) mkProfile;
in
mkProfile {
  imports = [
    ./nfs-fixes.nix
    ./nix-helpers.nix
    ./updates.nix
  ];

  requires.profiles = [
    # enable smart card support for personal computers
    "core/security/smartcard"
  ];

  boot.kernel.sysctl = {
    # bump up the inotify max watches to fix some file refresh issues
    "fs.inotify.max_queued_events" = 1048576;
    "fs.inotify.max_user_instances" = 1048576;
    "fs.inotify.max_user_watches" = 1048576;

    # required for WireGuard to work
    "net.ipv4.conf.all.log_martians" = false;
    "net.ipv4.conf.all.rp_filter" = false;
    "net.ipv4.conf.default.log_martians" = false;
    "net.ipv4.conf.default.rp_filter" = false;
  };

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

  networking = {
    # required for WireGuard to work
    firewall.checkReversePath = false;

    networkmanager = {
      enable = true;

      # stable randomised MAC address that resets at boot
      # wifi.macAddress = "stable";
      # ethernet.macAddress = "stable";

      # extraConfig = ''
      #     [connection]
      #     connection.stable-id=''${CONNECTION}/''${BOOT}
      # '';
    };
  };

  # add our custom fonts
  fonts = {
    fonts = with pkgs; [
      noto-fonts
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "FiraMono"
        ];
      })
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

  environment.systemPackages = with pkgs; [
    home-manager
  ];

  hardware.pulseaudio = {
    zeroconf = {
      publish.enable = true;
      discovery.enable = true;
    };

    tcp.enable = true;
  };

  # link the nixos config in the persistent volume to the temporary volume
  # TODO: SHOULD NOT BE IN HERE!! Should be under a mkIf guard once I add profile conditionals
  system.activationScripts.linkPersist = {
    text = ''
      mkPersistDir()
      {
          mkdir -p "$1"
          rm -rf "$2"
          ln -sT "$1" "$2"
      }

      setDirAcls()
      {
          chown -R root:sysconf "$1" > /dev/null 2>&1 || true
          chmod -R 0770 "$1" > /dev/null 2>&1 || true

          find "$1" -type d -exec chmod a+s {} + > /dev/null 2>&1 || true
          setfacl -R -d --set=u::rwX,g::rwX,o::0 "$1" > /dev/null 2>&1 || true
          setfacl -R --set=u::rwX,g::rwX,o::0 "$1" > /dev/null 2>&1 || true
      }

      mkPersistDir /persist/nixos /etc/nixos

      # correct the permissions
      setDirAcls /persist/nixos
      setDirAcls /persist/secrets
    '';

    deps = [ ];
  };
}
