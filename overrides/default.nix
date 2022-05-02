{
    modules = [
        "security/vault/keys.nix"
        "services/hardware/hp-ams.nix"
        "services/networking/firewall.nix"
        "services/networking/fort-validator.nix"
        "services/networking/tayga.nix"
        "services/security/vault-agent.nix"
        "system/boot/loader/systemd-boot/systemd-boot.nix"
        "virtualisation/containerd.nix"
    ];
    disabledModules = [];

    # allowed unfree packages
    unfree = [
        "hp-ams" "p4" "p4v" "steam" "steam-original" "steam-runtime"
        "nvidia-x11" "nvidia-settings" "nvidia-persistenced"
    ];

    packages = [(pkgs: final: prev: with pkgs; {
        # packages pulled from upstream
        inherit bird2 manix nixos-option;

        # previously upstreamed
        inherit fort-validator hp-ams vault-token-helper;
    })];
}