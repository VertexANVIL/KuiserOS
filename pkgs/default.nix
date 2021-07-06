final: prev: {
    # development
    qvtf = prev.callPackage ./development/libraries/qvtf { };
    vtflib = prev.callPackage ./development/libraries/vtflib { };
    #nodePackagesCustom = import ./development/node-packages { pkgs = final; };

    # misc
    intel-sgx-sdk = prev.callPackage (import ./misc/sgx { type = "sdk"; }) { };
    intel-sgx-psw = prev.callPackage (import ./misc/sgx { type = "psw"; }) { };

    # os-specific
    linuxPackages = import ./os-specific/linux { inherit final prev; };

    # tools
    calico-node = prev.callPackage ./tools/networking/calico/calico-node.nix { };
    calicoctl = prev.callPackage ./tools/networking/calico/calicoctl.nix { };
    inix-helper = import ./tools/package-management/inix-helper { inherit final prev; };

    # python
    # python3 = prev.python3.override {
    #     packageOverrides = import ./development/python-modules;
    # };

    # python37 = prev.python37.override {
    #     packageOverrides = import ./development/python-modules;
    # };

    # python38 = prev.python38.override {
    #     packageOverrides = import ./development/python-modules;
    # };
}
