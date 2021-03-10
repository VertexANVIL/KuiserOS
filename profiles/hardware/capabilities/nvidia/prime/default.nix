{ pkgs, ... }:
{
    hardware.nvidia = {
        prime = {
            offload.enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
        };

        powerManagement.enable = true;
    };

    services.xserver.displayManager.setupCommands = ''
        # External monitor support via Output Sink
        ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-G0 modesetting
    '';

    # TODO: figure out which one of these options it is that actually allows both of the monitors to work
    services.xserver.deviceSection = ''
        Option "ModeValidation" "AllowNon60hzmodesDFPModes, NoEDIDDFPMaxSizeCheck, NoVertRefreshCheck, NoHorizSyncCheck, NoDFPNativeResolutionCheck, NoMaxSizeCheck, NoMaxPClkCheck, AllowNonEdidModes, NoEdidMaxPClkCheck"
    '';
}