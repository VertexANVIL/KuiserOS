{ config, lib, pkgs, ... }:

with lib;

let
    inherit (lib.arnix.systemd) hardeningProfiles;
    cfg = config.services.hardware.hp-ams;

    fake-dpkg-query = pkgs.writeScriptBin "dpkg-query" ''
        #!${pkgs.runtimeShell}
        # returns nothing for now
    '';
in
{
    options = {
        services.hardware.hp-ams = {
            enable = mkEnableOption "HP Agentless Management Service";
        };
    };

    config = mkIf cfg.enable {
        systemd.services.hp-ams = {
            description = "HP Agentless Management Service for ProLiant";
            wantedBy = [ "multi-user.target" ];

            path = [ fake-dpkg-query ];

            serviceConfig = hardeningProfiles.isolate // {
                ExecStart = "${pkgs.hp-ams}/sbin/amsHelper -I0 -L -f";
                ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";

                Restart = "on-failure";
                RestartSec = "15s";

                # requires a little less restrictive permissions
                CapabilityBoundingSet = "CAP_SYS_ADMIN";
                ProcSubset = "all";
                PrivateDevices = false;
                PrivateNetwork = false;
                PrivateUsers = false;

                # needs the ipc syscall in order to run
                SystemCallFilter = subtractLists [ "~@ipc" ]
                    hardeningProfiles.networked.SystemCallFilter;

                # needs to access iLO devices
                DevicePolicy = "closed";
                DeviceAllow = [
                    "char-hpilo"
                    "char-ipmidev"
                ];
            };
        };

        # fake this for amsHelper, otherwise it will segfault
        environment.etc."debian_version".text = "10.9";
    };
}