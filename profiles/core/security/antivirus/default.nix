{ lib, pkgs, ... }:
{
    # enables the clamav antivirus
    services.clamav = {
        daemon.enable = true;
        updater.enable = true;
    };
}
