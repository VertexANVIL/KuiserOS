{
    imports = [ <nixpkgs/nixos/modules/virtualisation/openstack-config.nix> ];

    # Keep disabled! OpenStack DOES NOT like these.
    networking = {
        interfaces.ens3.tempAddress = "disabled";
        resolvconf.dnsExtensionMechanism = false;
    };
}