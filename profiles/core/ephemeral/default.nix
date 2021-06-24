{ lib, ... }:
{
    # reference: https://grahamc.com/blog/erase-your-darlings
    # nuke the temporary root volume on boot
    boot.initrd.postDeviceCommands = lib.mkAfter ''
        zfs rollback -r rpool/local/root@blank
    ''; # touch /etc/NIXOS

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
