{ pkgs, hardware, ... }:
{
    imports = [
        hardware.common-pc-laptop
        hardware.common-pc-laptop-ssd
        hardware.common-cpu-intel-kaby-lake
        ../../capabilities/fingerprint
        ../../capabilities/graphics/nvidia
        #../../capabilities/graphics/nvidia/prime
    ];

    # thunderbolt support
    services.hardware.bolt.enable = true;

    # use the newer DCAP SGX driver because we have FLC support
    security.sgx.packages.driver = pkgs.linuxPackages.intel-sgx-dcap;

    # enable nvidia support for Docker as we have a nvidia card
    virtualisation.docker.enableNvidia = true;
}