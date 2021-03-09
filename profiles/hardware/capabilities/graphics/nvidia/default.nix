{
    services = {
        xserver.videoDrivers = [ "nvidia" ];

        # enabling runtime power management on unsupported platforms doesn't hurt
        # (just means it will continue to be disabled)
        udev.extraRules = ''
            # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
            ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
            ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
            
            # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
            ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
            ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
        '';
    };

    boot.extraModprobeConfig = ''
        options nvidia "NVreg_DynamicPowerManagement=0x02"
    '';

    hardware.nvidia.modesetting.enable = true;
}