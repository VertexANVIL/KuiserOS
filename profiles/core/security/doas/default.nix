{ config, lib, pkgs, ... }:
{
  security = {
    # replace sudo with doas by default
    sudo.enable = lib.mkDefault false;

    doas = {
      enable = lib.mkDefault true;
      extraRules = [
        rec {
          groups = [ "wheel" ];
          noPass = !config.security.doas.wheelNeedsPassword;
          persist = !noPass;
          setEnv = [ "COLORTERM" "NIX_PATH" "PATH" ];
        }
      ];
    };
  };
}
