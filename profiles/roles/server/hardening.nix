{ lib, pkgs, ... }:
{
  # Extra security hardening options for servers
  nix = {
    useSandbox = true;
    allowedUsers = [ "@wheel" ];
    trustedUsers = [ "root" "@wheel" ];
  };

  # don't need ntfs for production
  boot.blacklistedKernelModules = [ "ntfs" ];
}
