{ lib, pkgs, ... }:
{
  boot = {
    tmpOnTmpfs = true; # TODO only if "big enough" ?
    cleanTmpDir = true;

    loader = {
      grub.configurationLimit = 10;

      systemd-boot = {
        # disables init=/bin/sh backdoor
        editor = lib.mkDefault false;
        configurationLimit = 10;
      };
    };
  };
}
