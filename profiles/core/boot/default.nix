{ pkgs, ... }:
{
    boot = {
        tmpOnTmpfs = true;
        cleanTmpDir = true;

        loader.systemd-boot = {
            enable = true;
            configurationLimit = 10;
        };
    };
}
