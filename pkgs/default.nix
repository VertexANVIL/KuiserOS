final: prev: {
    # applications
    juju = prev.callPackage ./applications/networking/juju { };
    enigma = prev.callPackage ./applications/games/enigma { };

    # development
    libcamera = prev.callPackage ./development/libraries/libcamera { };
    openenclave-sgx = prev.callPackage (import ./development/libraries/openenclave { type = "sgx"; }) { };
    qvtf = prev.callPackage ./development/libraries/qvtf { };
    vtflib = prev.callPackage ./development/libraries/vtflib { };
    #nodePackagesCustom = import ./development/node-packages { pkgs = final; };

    # misc
    intel-sgx-sdk = prev.callPackage (import ./misc/sgx { type = "sdk"; }) { };
    intel-sgx-psw = prev.callPackage (import ./misc/sgx { type = "psw"; }) { };

    # os-specific
    linuxPackages = import ./os-specific/linux { inherit final prev; };

    # tools
    calico = prev.callPackage ./tools/networking/calico { };
    calicoctl = prev.callPackage ./tools/networking/calico/calicoctl.nix { };
    fort-validator = prev.callPackage ./tools/networking/fort/validator { };
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
