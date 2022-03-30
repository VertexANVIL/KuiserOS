{ lib, pkgs, hardware, ... }:
let
    inherit (lib.kuiser) mkProfile;
in mkProfile {
    imports = [
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
            allow id 058f:9540 name "EMV Smartcard Reader" with-connect-type "not used"
            allow id 04f2:b604 name "Integrated Camera" with-connect-type "not used"
            allow id 04f2:b605 name "Integrated IR Camera" with-connect-type "not used"
            allow id 8087:0aaa with-connect-type "not used"
            allow id 06cb:009a with-connect-type "not used"
        '';
    };

    # hardware video offload
    environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}