{ pkgs, ... }:
{
    boot = {
        tmpOnTmpfs = true;
        cleanTmpDir = true;

        loader.grub = {
            enable = false; # TODO FOR THIS SHIT, most machines on arctarus use it
            configurationLimit = 10;
        };

        loader.systemd-boot = {
            enable = true;
            configurationLimit = 10;
        };
    };
}
