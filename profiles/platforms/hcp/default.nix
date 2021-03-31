{ lib, pkgs, ... }:
let
    inherit (lib.arnix) mkInputStorePath;
in {
    imports = [ ((mkInputStorePath "nixpkgs") + "/nixos/modules/virtualisation/openstack-config.nix") ];

    networking = {
        interfaces.ens3 = {
            useDHCP = true;

            # Keep disabled! OpenStack DOES NOT like these.
            tempAddress = "disabled";
        };

        resolvconf.dnsExtensionMechanism = false;
    };
}