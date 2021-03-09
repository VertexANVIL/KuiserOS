{ config, stdenv, lib, kernel, fetchurl, fetchFromGitHub, ... }:
assert lib.versionAtLeast kernel.version "5.10";

stdenv.mkDerivation rec {
    pname = "intel-sgx-dcap";
    version = "1.10";

    src = fetchFromGitHub {
        owner = "intel";
        repo = "SGXDataCenterAttestationPrimitives";
        rev = "DCAP_${version}";
        sha256 = "sha256-OR7T7XRFnsBH6ccwqWQQUHm3iF1moQnJH4dfez6b0TI=";
    };

    preBuild = "cd driver/linux";

    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = [ "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" ];
    
    installPhase = ''
        install -D intel_sgx.ko $out/lib/modules/${kernel.modDirVersion}/drivers/intel/sgx/intel_sgx.ko
    '';

    meta = with lib; {
        homepage = "https://github.com/intel/SGXDataCenterAttestationPrimitives";
        license = licenses.bsd1;
        description = "Kernel module for Intel SGX Datacenter Attestation Primitives";
        platforms = platforms.linux;
    };
}
