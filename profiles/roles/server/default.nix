{ lib, pkgs, repos, ... }: let
    inherit (lib.arnix) mkProf;
in {
    imports = (with repos.root; mkProf [
        # enable SSH by default for servers
        profiles.core.security.sshd
    ]) ++ [
        ./hardening.nix
    ];

    security = {
        doas.wheelNeedsPassword = false;
    };

    # disable to remove unnecessary overhead
    xdg.sounds.enable = false;
    services.udisks2.enable = false;
}