{
    modules = [
        "services/networking/firewall.nix"
        "services/networking/fort-validator.nix"
        "services/networking/tayga.nix"
        "virtualisation/containerd.nix"
    ];
    disabledModules = [];

    # allowed unfree packages
    unfree = [
        "p4" "p4v" "steam" "steam-original" "steam-runtime"
        "nvidia-x11" "nvidia-settings" "nvidia-persistenced"
    ];

    packages = [(pkgs: final: prev: with pkgs; {
        # needed for our patch
        #inherit nixFlakes nixUnstable; # WHAT ???

        # packages pulled from upstream
        inherit juju enigma libcamera openenclave-sgx fort-validator;
    })];
}