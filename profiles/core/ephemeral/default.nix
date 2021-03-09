{ lib, ... }:
{
    # reference: https://grahamc.com/blog/erase-your-darlings
    # nuke the temporary root volume on boot
    boot.initrd.postDeviceCommands = lib.mkAfter ''
        zfs rollback -r rpool/local/root@blank
    ''; # touch /etc/NIXOS

    # link the config in the persistent volume to the temporary volume
    system.activationScripts.linkPersist = {
        text = ''
            mkPersistDir()
            {
                mkdir -p "$1"
                rm -rf "$2"
                ln -sT "$1" "$2"
            }

            mkPersistDir /persist/nixos /etc/nixos
            mkPersistDir /persist/etc/NetworkManager/system-connections /etc/NetworkManager/system-connections
            mkPersistDir /persist/var/lib/bluetooth /var/lib/bluetooth

            # make sure /persist/nixos has correct perms, fine if it doesn't exist yet
            chown -R root:sysconf /persist/nixos > /dev/null 2>&1 || true
            find /persist/nixos -type d -exec chmod a+s {} + > /dev/null 2>&1 || true
            setfacl -R -d --set=u::rwX,g::rwX,o::0 /persist/nixos > /dev/null 2>&1 || true
            setfacl -R --set=u::rwX,g::rwX,o::0 /persist/nixos > /dev/null 2>&1 || true
        '';

        deps = [];
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
        };
    };
}
