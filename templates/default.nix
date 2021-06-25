{ lib, ... }: let
    inherit (lib.arnix) mkProfile;

    mkTemplate = p: mkProfile {
        requires.profiles = [ "roles/iso" ] ++ p;
    };
in {
    default = mkTemplate [ ];
}
