{ config, lib, ...}:

with lib;
let
    cfg = config.security.sftpjail;

    userSubmodule = { ... }: {
        options = {
            enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enables the SFTP jail for this user";
            };

            mounts = mkOption {
                type = types.attrs;
                default = {};
                description = "Mapping of paths inside the user's SFTP jail to bind";
            };
        };
    };
in {
    options = {
        security.sftpjail = {
            enable = mkEnableOption "SFTP Jail";

            jailPath = mkOption {
                type = types.path;
                default = "/run/sftpjail";
                description = "Directory to store user jails";
            };

            users = mkOption {
                type = types.attrsOf (types.submodule userSubmodule);
                default = {};
                description = "Users to enable the SFTP jail for";
            };
        };
    };

    config = mkIf cfg.enable {
        services.openssh.extraConfig = ''
            Match Group sftpjail
                ForceCommand internal-sftp
                ChrootDirectory ${cfg.jailPath}
                X11Forwarding no
                AllowTcpForwarding no
        '';

        # create the temporary directories for each user
        systemd.tmpfiles.rules = [
            "d ${cfg.jailPath} 0755 root root - -"
            "z ${cfg.jailPath} 0755 root root - -"
        ] ++ (flatten (flip mapAttrsToList cfg.users (name: user: [
            "d ${cfg.jailPath}/home/${name} 0700 ${name} nogroup - -"
            "z ${cfg.jailPath}/home/${name} 0700 ${name} nogroup - -"
        ])));

        # create our filesystem binds
        fileSystems = mkMerge (flip mapAttrsToList cfg.users (name: user: 
            flip mapAttrs' user.mounts (dest: src: nameValuePair "${cfg.jailPath}/home/${name}/${dest}" {
                device = src;
                options = [ "rw" "bind" "noauto" "x-systemd.automount" ];
            })
        ));

        # setup the user attributes
        users = {
            users = flip mapAttrs cfg.users (name: user: {
                home = "/home/${name}";
                extraGroups = [ "sftpjail" ];
            });

            groups.sshjail = {};
        };
    };
}