{ lib, ... }: let
    inherit (lib.arnix) mkProfile;
in mkProfile {
    imports = [
        ./hardening.nix
    ];

    requires.profiles = [
        # enable SSH by default for servers
        "core/security/sshd"
    ];

    security = {
        doas.wheelNeedsPassword = false;
    };

    # disable to remove unnecessary overhead
    xdg.sounds.enable = false;
    services.udisks2.enable = false;
}