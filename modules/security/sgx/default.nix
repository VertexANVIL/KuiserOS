{ config, lib, pkgs, ... }:
with lib;
let
    inherit (lib.arnix.systemd) hardeningProfiles;

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
                isSystemUser = true;
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
            
            serviceConfig = hardeningProfiles.socketed // {
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

                # requires a little less restrictive permissions
                MemoryDenyWriteExecute = false;
                PrivateDevices = false;
                PrivateNetwork = false;

                # needs the ipc syscall in order to run
                SystemCallFilter = subtractLists [ "~@ipc" ]
                    hardeningProfiles.networked.SystemCallFilter;

                # needs to access SGX devices
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
