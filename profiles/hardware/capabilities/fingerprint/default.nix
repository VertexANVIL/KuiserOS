{ pkgs, ... }:
{
  services.fprintd.enable = true;

  environment = {
    systemPackages = with pkgs; [ libfprint ];

    # add the dir for storing enrolled prints to persistent volume
    persistence."/persist".directories = [ "/var/lib/fprint" ];
  };
}
