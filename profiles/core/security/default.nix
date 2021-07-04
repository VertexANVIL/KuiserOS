{ config, lib, pkgs, ... }: let
    inherit (lib.arnix) mkProfile;
in mkProfile {
    requires.profiles = [
        "core/security/certs"
        "core/security/doas"
        "core/security/hardening"
        "core/security/pam"
    ];

    users = {
        mutableUsers = lib.mkDefault false;

        # this group owns /persist/nixos configuration
        groups.sysconf.gid = 600;
    };

    # enable auditing
    security.auditd.enable = true;

    # firewall hardening - don't allow ping by default
    # (for routers, it's overridden in their templates)
    networking.firewall = {
        allowPing = lib.mkDefault false;
        logRefusedConnections = lib.mkDefault false;
    };
}
