{
  # Same as below, but does this actually do anything??
  boot.kernelParams = [
    "iwlwifi.11n_disable=4"
    "usbcore.quirks=17ef:3082:k"
  ];

  services.udev.extraRules = ''
    # Disable runtime PM for Lenovo Thunderbolt docks, as it can't handle it
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0x17ef", ATTR{idProduct}=="0x3082", TEST=="power/control", ATTR{power/control}="on"
  '';
}
