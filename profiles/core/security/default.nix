{ config, lib, pkgs, ... }:
{
    imports = [
        ./certs
        ./hardening
        ./pam
    ];

    users = {
        mutableUsers = lib.mkDefault false;

        # this group owns /persist/nixos configuration
        groups.sysconf.gid = 600;
    };

    security = {
        # enable auditing
        auditd.enable = true;

        # replace sudo with doas by default
        sudo.enable = lib.mkDefault false;

        doas = {
            enable = lib.mkDefault true;
            extraRules = [
                rec {
                    groups = [ "wheel" ];
                    noPass = !config.security.doas.wheelNeedsPassword;
                    persist = !noPass;
                    setEnv = [ "COLORTERM" "NIX_PATH" "PATH" ];
                }
            ];
        };
    };

    # firewall hardening - don't allow ping by default
    # (for routers, it's overridden in their templates)
    networking.firewall = {
        allowPing = lib.mkDefault false;
        logRefusedConnections = lib.mkDefault false;
    };
}
