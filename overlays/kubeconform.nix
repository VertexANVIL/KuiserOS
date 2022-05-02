final: prev: {
    kubeconform = prev.kubeconform.overrideAttrs (o: {
        patches = [ ../pkgs/applications/networking/cluster/kubeconform/0001-add-group.patch ];
    });
}
