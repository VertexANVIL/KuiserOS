{ config, lib, pkgs, ... }:
with lib;
let
    cfg = config.security.sgx;
in
{
    options.security.sgx = {
        enable = mkEnableOption "Intel SGX";

        config = mkOption {
            type = types.lines;
            default = "";
            description = "Configuration for the SGX daemon.";
        };

        packages = {
            psw = mkOption {
                default = pkgs.intel-sgx-psw;
                defaultText = "pkgs.intel-sgx-psw";
                description = "The SGX PSW (platform software) package to use.";
            };

            sdk = mkOption {
                default = pkgs.intel-sgx-sdk;
                defaultText = "pkgs.intel-sgx-sdk";
                description = "The SGX SDK (software development kit) package to use.";
            };

            driver = mkOption {
                type = types.package;
                default = pkgs.linuxPackages.intel-sgx-sgx1;
                defaultText = "pkgs.linuxPackages.intel-sgx-sgx1";
                example = literalExample "pkgs.linuxPackages.intel-sgx-dcap";
                description = "The SGX driver package to use.";
            };
        };
    };

    config = mkIf cfg.enable {
        boot.extraModulePackages = [ cfg.packages.driver ];
        services.udev.packages = [ cfg.packages.psw ];

        environment.systemPackages = with pkgs; [ intel-sgx-sdk openenclave-sgx ]; # TEMP

        # aesmd depends on auditd
        security.auditd.enable = true;

        # write service config file
        environment.etc."aesmd.conf".text = cfg.config;

        # create service user and groups
        users = {
            users.aesmd = {
                group = "aesmd";
                extraGroups = [ "sgx_prv" ];
                description = "Intel SGX Service Account";
            };

            groups = {
                aesmd = {};
                sgx_prv = {};
            };
        };

        systemd.services.aesmd = let
            path = "${cfg.packages.psw}/aesm";
        in {
            description = "Intel(R) Architectural Enclave Service Manager";
            after = [ "syslog.target" "network.target" "auditd.service" ];
            wantedBy = [ "multi-user.target" ];

            # restart when config file changes
            restartTriggers = [ config.environment.etc."aesmd.conf".source ];

            environment = {
                NAME = "aesm_service";
                AESM_PATH = "/var/opt/aesmd";
                LD_LIBRARY_PATH = "${cfg.packages.psw}/lib:${path}";
            };
            
            serviceConfig = {
                # for strace: ${pkgs.strace}/bin/strace -o /var/opt/aesmd/trace.log
                ExecStart = "${path}/aesm_service --no-daemon";
                ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                ExecStartPre = [ "${pkgs.coreutils}/bin/mkdir -p /var/opt/aesmd/data /var/opt/aesmd/fwdir/data" ];

                Restart = "on-failure";
                RestartSec = "15s";

                # environment
                User = "aesmd";
                Group = "aesmd";

                WorkingDirectory = "/var/opt/aesmd";
                RuntimeDirectory = "aesmd";
                RuntimeDirectoryMode = "0755";
                ReadWritePaths = [ "/var/opt/aesmd" ];

                # sandboxing
                CapabilityBoundingSet = "";
                LockPersonality = true;
                MemoryDenyWriteExecute = false;
                NoNewPrivileges = true;
                RemoveIPC = true;
                ProcSubset = "pid";

                PrivateDevices = false;
                PrivateMounts = true;
                PrivateNetwork = false;
                PrivateTmp = true;
                PrivateUsers = true;

                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectHostname = true;
                ProtectProc = "noaccess";
                ProtectSystem = "strict";
                RestrictAddressFamilies = [ "~AF_INET" "~AF_INET6" ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;

                SystemCallFilter = [
                    "@system-service"
                    "~@aio" "~@chown" "~@keyring" "~@memlock"
                    "~@resources" "~@privileged" "~@setuid" "~@sync" "~@timer"
                ];
                SystemCallArchitectures = "native";
                SystemCallErrorNumber = "EPERM";

                DevicePolicy = "closed";
                DeviceAllow = [
                    "/dev/isgx rw"
                    "/dev/sgx rw"
                    "/dev/sgx/enclave rw"
                    "/dev/sgx/provision rw"
                ];
            };
        };

        systemd.tmpfiles.rules = [
            "d /var/opt/aesmd 0750 aesmd aesmd - -"
            "z /var/opt/aesmd 0750 aesmd aesmd - -"
        ];
    };
}
