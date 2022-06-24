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

    # set up our zfs filesystems
    fileSystems = {
        #"/" = {
        #    device = "rpool/local/root";
        #    fsType = "zfs";
        #};

	    "/" = {
            device = "none";
            fsType = "tmpfs";
            options = ["size=8G" "mode=755"];
	    };

        "/nix" = {
            device = "rpool/local/nix";
            fsType = "zfs";
        };

        "/home" = {
            device = "rpool/safe/home";
            fsType = "zfs";
        };
    };
}
