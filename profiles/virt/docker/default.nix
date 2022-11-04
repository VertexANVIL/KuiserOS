{
  virtualisation = {
    # containerd = {
    #   enable = true;
    #   settings.plugins."io.containerd.grpc.v1.cri" = {
    #     containerd.snapshotter = "native";
    #   };
    # };

    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune.enable = true;

      #extraOptions = "--containerd /run/containerd/containerd.sock";
    };
  };
}
