{ config, lib, pkgs, repos, ... }: let
    inherit (lib.arnix) mkProf;
in {
    # enable development documentation
    documentation.dev.enable = true;

    # enable kernel debugging disabled in security hardening profile
    boot.kernel.sysctl."kernel.ftrace_enabled" = true;

    # wireshark must be enabled here, should it really be though?
    programs.wireshark.enable = true;

    # enable rabbitmq on localhost for various purposes
    services.rabbitmq.enable = true;
}