{ pkgs, ... }:
{
  # Vagrant and other applications that dynamically modify /etc/exports need this
  environment.etc.exports.enable = false;
  networking.firewall.extraCommands = ''
    ip46tables -I nixos-fw 3 -i virbr+ -p tcp --match multiport --dports 111,2049,4000,4001,4002 -j nixos-fw-accept
    ip46tables -I nixos-fw 3 -i virbr+ -p udp --match multiport --dports 111,2049,4000,4001,4002 -j nixos-fw-accept
  '';

  systemd.services.nfs-mountd.restartTriggers = [ "/etc/exports" ];
  system.activationScripts.nfs-exports = "touch /etc/exports";

  # QoL for Vagrant
  security.sudo.extraConfig = ''
    Cmnd_Alias VAGRANT_EXPORTS_CHOWN = ${pkgs.coreutils}/bin/chown 0\:0 /tmp/vagrant[a-z0-9-]*
    Cmnd_Alias VAGRANT_EXPORTS_MV = ${pkgs.coreutils}/bin/mv -f /tmp/vagrant[a-z0-9-]* /etc/exports
    Cmnd_Alias VAGRANT_NFSD_APPLY = ${pkgs.nfs-utils}/bin/exportfs -ar
    %wheel ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_APPLY
  '';
}
