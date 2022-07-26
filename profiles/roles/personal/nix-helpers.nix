{ lib, pkgs, ... }:
let
  inixCli = pkgs.writeShellScriptBin "inix" ''
    IFS=';' read -ra ARGS <<< $(${pkgs.inix-helper}/bin/inix-helper)
    nix "$@" "''\${ARGS[@]}"
  '';

  # Little helper to run nixos-rebuild while overriding the KuiserOS path
  nrbScript = pkgs.writeShellScriptBin "nrb" ''
    IFS=';' read -ra ARGS <<< $(cd /etc/nixos && ${pkgs.inix-helper}/bin/inix-helper)
    sudo nixos-rebuild "$@" "''\${ARGS[@]}"
  '';
in
{
  environment.systemPackages = [ inixCli nrbScript ];
}
