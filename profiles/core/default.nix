{ config, lib, pkgs, ... }:
let
  inherit (lib.kuiser) mkProfile systemGlobal;
  system = systemGlobal { inherit pkgs; };
in
mkProfile {
  requires.profiles = [
    "core/boot"
    "core/nix"
    "core/security"

    # global hardware profiles
    "hardware/common"
  ];

  networking.useDHCP = false;
  hardware.enableRedistributableFirmware = true;
  #documentation.nixos.includeAllModules = true;

  environment = {
    systemPackages = system.packages;
    variables = system.variables;
    shellAliases = system.aliases;
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

    # set required defaults for git
    git = {
      enable = true;

      # disable git "safe directory" feature as it breaks rebuilds
      config.safe.directory = [ "*" ];
    };
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

    # enable the system MTA
    postfix.enable = true;
  };
}
