final: prev: {
    # applications
    juju = prev.callPackage ./applications/networking/juju { };
    enigma = prev.callPackage ./applications/games/enigma { };

    # development
    libcamera = prev.callPackage ./development/libraries/libcamera { };
    openenclave-sgx = prev.callPackage (import ./development/libraries/openenclave { type = "sgx"; }) { };
    #nodePackagesCustom = import ./development/node-packages { pkgs = final; };

    # misc
    intel-sgx-sdk = prev.callPackage (import ./misc/sgx { type = "sdk"; }) { };
    intel-sgx-psw = prev.callPackage (import ./misc/sgx { type = "psw"; }) { };

    # os-specific
    linuxPackages = import ./os-specific/linux { inherit final prev; };

    # tools
    colmena = prev.callPackage ./tools/package-management/colmena { };
}
