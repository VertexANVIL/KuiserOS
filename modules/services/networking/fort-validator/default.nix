{ config, lib, pkgs, ... }:

with lib;

let
    inherit (lib.arnix.systemd) hardeningProfiles;
    cfg = config.services.fort-validator;
in
{
    options = {
        services.fort-validator = {
            enable = mkEnableOption "FORT Validator";
        };
    };

    config = mkIf cfg.enable {
        users = {
            users.fort-validator = {
                name = "fort-validator";
                group = "fort-validator";
                isSystemUser = true;
                description = "FORT Validator user";
            };

            groups.fort-validator = {};
        };

        systemd = {
            services = {
                init-fort-tals = {
                    description = "Create and download RPKI TALs for FORT.";

                    wantedBy = [ "multi-user.target" ];
                    wants = [ "network-online.target" ];
                    after = [ "network-online.target" ];

                    serviceConfig = {
                        Type = "oneshot";
                        User = "fort-validator";
                        Group = "fort-validator";
                    };

                    script = ''
                        TALS_DIR="/var/lib/fort/tals"
                        if [ ! -d "$TALS_DIR" ]; then
                            mkdir -p "$TALS_DIR"
                            printf 'yes\n' | ${pkgs.fort-validator}/bin/fort --init-tals --tal "$TALS_DIR"
                        else
                            echo "skipping: TALs already loaded"
                        fi
                    '';
                };

                fort-validator = {
                    description = "FORT Validator";

                    wantedBy = [ "multi-user.target" ];
                    wants = [ "network-online.target" ];
                    after = [ "network-online.target" ];

                    path = [ pkgs.rsync ];

                    serviceConfig = hardeningProfiles.networked // {
                        User = "fort-validator";
                        Group = "fort-validator";
                        ReadWritePaths = "/var/lib/fort";
                        ExecStart = "${pkgs.fort-validator}/bin/fort --tal /var/lib/fort/tals --local-repository /var/lib/fort/cache --server.address \"127.0.0.1,::1\" --server.port 3323";
                        ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";
                        KillSignal = "SIGINT";
                        TimeoutStopSec = "30s";
                        Restart = "always";

                        # requires the ipc syscall in order to not crash
                        SystemCallFilter = subtractLists [ "~@ipc" ] hardeningProfiles.networked.SystemCallFilter;
                    };
                };
            };

            tmpfiles.rules = [
                "d /var/lib/fort 0755 fort-validator fort-validator - -"
                "z /var/lib/fort 0755 fort-validator fort-validator - -"
            ];
        };
    };
}