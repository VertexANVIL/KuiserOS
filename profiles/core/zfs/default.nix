{
    boot.supportedFilesystems = [ "zfs" ];
    virtualisation.docker.storageDriver = "zfs";

    services.zfs = {
        trim.enable = true;
        autoScrub.enable = true;
        autoSnapshot.enable = true;
    };
}