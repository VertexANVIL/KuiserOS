{
    # experimental configuration to try and fix the internal mic
    boot.extraModprobeConfig = ''
        options snd-hda-intel patch=hda-jack-retask.fw,hda-jack-retask.fw,hda-jack-retask.fw,hda-jack-retask.fw
    '';

    hardware.firmware = [(pkgs.runCommand "hda-jack-retask" {} ''
        mkdir -pv $out/lib/firmware
        cp -vi ${./hda-jack-retask.fw} $out/lib/firmware/hda-jack-retask.fw
   '')];

    #sound.extraConfig = ''
    #    options snd-hda-intel model=laptop-dmic
    #'';
}
