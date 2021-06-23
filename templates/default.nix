{ lib, repos, ... }: let
    inherit (lib.arnix) mkProf;
    inherit (repos.self) profiles;

    mkTemplate = p: {
        imports = mkProf [ profiles.roles.iso ] ++ p;
    };
in {
    default = mkTemplate [ ];
}
