{
    modules = [
        "security/vault/keys.nix"
        "services/hardware/hp-ams.nix"
        "services/networking/firewall.nix"
        "services/networking/fort-validator.nix"
        "services/networking/tayga.nix"
        "services/security/vault-agent.nix"
        "virtualisation/containerd.nix"
    ];
    disabledModules = [];

    # allowed unfree packages
    unfree = [
        "hp-ams" "p4" "p4v" "steam" "steam-original" "steam-runtime"
        "nvidia-x11" "nvidia-settings" "nvidia-persistenced"
    ];

    packages = [(pkgs: final: prev: with pkgs; {
        # needed for our patch
        #inherit nixFlakes nixUnstable; # WHAT ???

        # packages pulled from upstream
        inherit juju enigma libcamera openenclave-sgx fort-validator hp-ams;
    })];
}