{
    boot.supportedFilesystems = [ "zfs" ];
    virtualisation.docker.storageDriver = "zfs";

    services.zfs = {
        # regular sanitisation
        trim.enable = true;
        autoScrub.enable = true;

        # fine to enable by default, because it only affects datasets
        # marked with the com.sun:auto-snapshot attribute
        autoSnapshot.enable = true;
    };
}