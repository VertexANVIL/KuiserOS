{ pkgs, ... }:
{
    boot = {
        tmpOnTmpfs = true; # TODO only if "big enough" ?
        cleanTmpDir = true;

        loader = {
            grub.configurationLimit = 10;
            systemd-boot.configurationLimit = 10;
        };
    };
}
