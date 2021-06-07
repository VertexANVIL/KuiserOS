{ ... }:
rec {
    hardeningProfiles.isolate = {
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        IPAddressDeny = "any";
        KeyringMode = "private";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        NotifyAccess = "none";
        ProcSubset = "pid";
        RemoveIPC = true;

        PrivateDevices = true;
        PrivateMounts = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        PrivateUsers = true;

        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = "";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;

        SystemCallFilter = [
            "@system-service"
            "~@aio" "~@clock" "~@cpu-emulation" "~@chown" "~@debug" "~@ipc" "~@keyring"
            "~@memlock" "~@module" "~@mount" "~@raw-io" "~@reboot" "~@swap"
            "~@privileged" "~@resources" "~@setuid" "~@sync" "~@timer"
        ];
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
    };

    hardeningProfiles.networked = hardeningProfiles.isolate // {
        IPAddressDeny = [ "" ];
        PrivateNetwork = "no";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
    };

    hardeningProfiles.socketed = hardeningProfiles.isolate // {
        RestrictAddressFamilies = [ "AF_UNIX" ];
    };
}