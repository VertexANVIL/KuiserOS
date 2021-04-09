{ lib, ... }:
{
    # reference: https://grahamc.com/blog/erase-your-darlings
    # nuke the temporary root volume on boot
    boot.initrd.postDeviceCommands = lib.mkAfter ''
        zfs rollback -r rpool/local/root@blank
    ''; # touch /etc/NIXOS

    # link the nixos config in the persistent volume to the temporary volume
    system.activationScripts.linkPersist = {
        text = ''
            mkPersistDir()
            {
                mkdir -p "$1"
                rm -rf "$2"
                ln -sT "$1" "$2"
            }

            setDirAcls()
            {
                chown -R root:sysconf "$1" > /dev/null 2>&1 || true
                find "$1" -type d -exec chmod a+s {} + > /dev/null 2>&1 || true
                setfacl -R -d --set=u::rwX,g::rwX,o::0 "$1" > /dev/null 2>&1 || true
                setfacl -R --set=u::rwX,g::rwX,o::0 "$1" > /dev/null 2>&1 || true
            }

            mkPersistDir /persist/nixos /etc/nixos

            # correct the permissions
            setDirAcls /persist/nixos
            setDirAcls /persist/secrets
        '';

        deps = [];
    };

    environment.persistence."/persist" = {
        directories = [
            "/var/log"
            "/var/lib/bluetooth"
            "/var/lib/systemd/coredump"
            "/etc/NetworkManager/system-connections"
        ];

        files = [
            "/etc/machine-id"
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_rsa_key"
        ];
    };

    # set up our zfs filesystems
    fileSystems = {
        "/" = {
            device = "rpool/local/root";
            fsType = "zfs";
        };

        "/nix" = {
            device = "rpool/local/nix";
            fsType = "zfs";
        };

        "/home" = {
            device = "rpool/safe/home";
            fsType = "zfs";
        };

        "/persist" = {
            device = "rpool/safe/persist";
            fsType = "zfs";
            neededForBoot = true;
        };
    };
}
