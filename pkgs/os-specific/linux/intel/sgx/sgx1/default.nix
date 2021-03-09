{ config, stdenv, lib, kernel, fetchurl, fetchFromGitHub, ... }:
assert lib.versionAtLeast kernel.version "5.10";

stdenv.mkDerivation rec {
    pname = "intel-sgx-driver";
    version = "master";

    src = fetchFromGitHub {
        owner = "intel";
        repo = "linux-sgx-driver";
        rev = "0373e2e8b96d9a261657b7657cb514f003f67094";
        sha256 = "sha256-PSPKTBQYsCUoEOi1VqY9MmNyThr5t2rLuz9AGMsho6Q=";
    };

    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = [ "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" ];

    installPhase = ''
        install -D isgx.ko $out/lib/modules/${kernel.modDirVersion}/drivers/intel/sgx/isgx.ko
    '';

    meta = with lib; {
        homepage = "https://01.org/intel-softwareguard-extensions";
        license = licenses.bsd1;
        description = "Intel SGX Linux Driver";
        platforms = platforms.linux;
    };
}
