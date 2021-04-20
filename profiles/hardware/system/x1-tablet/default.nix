{ pkgs, hardware, ... }:
{
    imports = [
        hardware.common-pc-laptop
        hardware.common-pc-laptop-ssd
        hardware.common-cpu-intel-kaby-lake
    ];

    boot = {
        extraModprobeConfig = ''
            options thinkpad_acpi fan_control=1 experimental=1
        '';

        # we're hidpi so use lower res for boot
        loader.systemd-boot.consoleMode = "1";

        # load spidev to support binding the fingerprint reader to it later
        kernelModules = [ "spidev" ];
        kernelPatches = [
            {
                name = "tpx1-cover";
                patch = ./tpx1-cover.patch;
            }
            # {
            #     name = "ov8858-camera";
            #     patch = ./ov8858-camera.patch;
            #     extraConfig = ''
            #         PMIC_OPREGION y
            #         STAGING_MEDIA y
            #         INTEL_ATOMISP y
            #         VIDEO_ATOMISP m
            #         VIDEO_ATOMISP_IMX m
            #         VIDEO_ATOMISP_OV8858 m
            #         VIDEO_ATOMISP_MSRLIST_HELPER m
            #         VIDEO_IPU3_IMGU m
            #     '';
            # }
        ];

        # enable this block for kernel module iteration
        # must build with i.e `sudo ./cursed-rebuild switch --impure`
        # kernelPackages = let kernel = (pkgs.linuxManualConfig {
        #     inherit (pkgs) stdenv;
        #     version = "5.9.0";

        #     src = /home/alex/src/external/kernel/linux;
        #     configfile = /home/alex/src/external/kernel/kernel.conf;
        #     allowImportFromDerivation = true;
        # }); in pkgs.linuxPackagesFor kernel;
    };

    hardware = {
        video.hidpi.enable = true;
        sensor.iio.enable = true;
        usbWwan.enable = true;
    };

    services = {
        fprintd.enable = true;
        neard.enable = true;

        # gpsd = {
        #     enable = true;
        #     device = "/dev/ttyUSB1";
        # };

        logind = {
            # properly sleep on lid close
            lidSwitchDocked = "suspend";
        };

        # binds the spidev driver to the fingerprint reader
        # so it's accessible under /dev/spidev in userspace
        udev.extraRules = let script = pkgs.writeShellScript "" ''
            echo spidev > "$1/driver_override" && echo "$2" > "$1/subsystem/drivers/spidev/bind"
        ''; in ''
            ACTION=="add|change", SUBSYSTEM=="spi", ENV{MODALIAS}=="acpi:SYNA8002:", PROGRAM+="${script} %S%p %k"
        '';

        usbguard = {
            enable = true;
            rules = ''
                allow id 17ef:60b5 name "ThinkPad X1 Tablet Thin Keyboard Gen 3" with-connect-type "hotplug"
                allow id 1199:9079 name "Sierra Wireless EM7455 Qualcomm\xc2\xae Snapdragon\xe2\x84\xa2 X7 LTE-A" with-connect-type "hardwired"
                allow id 04ca:706b name "Integrated Camera" with-connect-type "hardwired"
                allow id 8087:0a2b with-connect-type "hardwired"
            '';
        };

        hardware.bolt.enable = true;
    };

    # hardware video offload
    environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
