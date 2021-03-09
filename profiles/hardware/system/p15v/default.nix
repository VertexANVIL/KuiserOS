{ pkgs, hardware, ... }:
{
    imports = [
        hardware.common-pc-laptop
        hardware.common-pc-laptop-ssd
        hardware.common-cpu-intel-kaby-lake
        ../../capabilities/fingerprint
    ];

    # use the newer DCAP SGX driver because we have FLC support
    security.sgx.packages.driver = pkgs.linuxPackages.intel-sgx-dcap;
}