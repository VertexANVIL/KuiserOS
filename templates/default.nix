{ lib, ... }:
let
  inherit (lib.kuiser) mkProfile;

  mkTemplate = p: mkProfile {
    requires.profiles = [ "roles/iso" ] ++ p;
  };
in
{
  default = mkTemplate [ ];
}
