{ lib, pkgs, hardware, ... }:
let
  inherit (lib.kuiser) mkProfile;
in
mkProfile {
  imports = [
    hardware.common-pc
    hardware.common-pc-laptop
    hardware.common-pc-laptop-ssd
    hardware.common-cpu-intel-kaby-lake
  ];

  requires.profiles = [
    "hardware/capabilities/fingerprint"
    "hardware/capabilities/graphics/nvidia"
    "hardware/capabilities/graphics/nvidia/prime"
  ];

  services = {
    # thunderbolt support
    hardware.bolt.enable = true;

    usbguard.rules = ''
      allow id 058f:9540 name "EMV Smartcard Reader" via-port "1-11" with-interface 0b:00:00 with-connect-type "not used"
      allow id 04f2:b604 name "Integrated Camera" via-port "1-8" with-interface { 0e:01:00 0e:02:00 0e:02:00 0e:02:00 0e:02:00 0e:02:00 0e:02:00 0e:02:00 0e:02:00 } with-connect-type "not used"
      allow id 04f2:b605 name "Integrated IR Camera" via-port "1-12" with-interface { 0e:01:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 0e:02:01 } with-connect-type "not used"
      allow id 8087:0aaa via-port "1-14" with-interface { e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 e0:01:01 } with-connect-type "not used"
      allow id 06cb:009a via-port "1-9" with-interface ff:00:00 with-connect-type "not used"
    '';
  };

  # hardware video offload
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
