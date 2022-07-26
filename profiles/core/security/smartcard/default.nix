{ config, lib, pkgs, ... }:
{
  services = {
    pcscd = {
      enable = true;
      plugins = with pkgs; [ ccid acsccid pcsc-cyberjack ];
    };

    udev.packages = with pkgs; [
      yubikey-personalization
      libu2f-host
    ];
  };

  # allow all regular users to access pcscd cards
  # (this is required to prevent pcscd from blocking access from docker when the uid is 1000)
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
        if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
            action.id == "org.debian.pcsc-lite.access_card") &&
            subject.isInGroup("users"))
        {
            return polkit.Result.YES;
        }
    });
  '';

  environment.systemPackages = with pkgs; [ opensc ];
}
