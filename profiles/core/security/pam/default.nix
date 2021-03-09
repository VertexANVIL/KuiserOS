{ config, lib, pkgs, ... }:
{
    security.pam.u2f = {
        enable = false; # todo
        control = "sufficient";
    };
}