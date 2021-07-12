{ lib, pkgs, ... }:
let
    inherit (lib.kuiser) mkInputStorePath;
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

    # override the openstack-init script, because not every VM has user data and this causes the service to crash
    systemd.services.openstack-init.script = let
        script = import ./openstack-metadata-fetcher.nix {
            targetRoot = "/";
            wgetExtraOptions = "--retry-connrefused";
        };
    in lib.mkForce script;
}