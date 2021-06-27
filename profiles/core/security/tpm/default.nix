{ pkgs, ... }:
{
    services.tcsd.enable = true;

    environment.systemPackages = with pkgs; [ tpm-tools ];
}