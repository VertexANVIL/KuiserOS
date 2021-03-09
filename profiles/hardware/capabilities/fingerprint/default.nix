{ pkgs, ... }:
{
    services.fprintd.enable = true;
    environment.systemPackages = with pkgs; [ libfprint ];
}