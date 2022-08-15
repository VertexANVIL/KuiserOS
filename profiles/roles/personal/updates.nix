{ config, lib, pkgs, ... }:
{
  # Configures automatic updates
  system.autoUpgrade = {
    enable = true;
    flake = "git+file:///persist/nixos";
    flags = [ "--update-input" "nixpkgs" ];
  };
}
