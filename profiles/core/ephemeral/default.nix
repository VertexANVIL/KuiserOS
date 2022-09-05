{ lib, ... }:
{
  # reference: https://grahamc.com/blog/erase-your-darlings
  # nuke the temporary root volume on boot
  boot.initrd.postDeviceCommands = lib.mkOrder 5000 ''
    zfs rollback -r rpool/local/root@blank
  ''; # touch /etc/NIXOS

  environment.persistence."/persist" = {
    directories = [
      "/var/log"
      "/var/lib"
      "/etc/NetworkManager/system-connections"
      "/etc/wireguard"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key"
    ];

    hideMounts = true;
  };

  # set up our zfs filesystem
  fileSystems."/persist" = {
    device = "rpool/safe/persist";
    fsType = "zfs";
    neededForBoot = true;
  };
}
