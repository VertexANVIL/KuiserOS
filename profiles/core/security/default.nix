{ config, lib, pkgs, ... }: let
    inherit (lib.kuiser) mkProfile;
in mkProfile {
    requires.profiles = [
        "core/security/antivirus"
        "core/security/certs"
        "core/security/doas"
        "core/security/hardening"
    ];

    users = {
        mutableUsers = lib.mkDefault false;

        # this group owns /persist/nixos configuration
        groups.sysconf.gid = 600;
    };
}
