{ config, lib, pkgs, ... }:

# Useful shared base configuration for NixOS routers
let
  inherit (lib) mkForce;

  python-custom-pkgs = python-packages: with python-packages; [ pyroute2 ];
  python-custom = with pkgs; python3.withPackages python-custom-pkgs;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = mkForce 1;
    "net.ipv6.conf.all.forwarding" = mkForce 1;

    # disable strict reverse path set in the hardening profile
    "net.ipv4.conf.all.log_martians" = false;
    "net.ipv4.conf.all.rp_filter" = false;
    "net.ipv4.conf.default.log_martians" = false;
    "net.ipv4.conf.default.rp_filter" = false;
  };

  networking = {
    firewall = {
      allowPing = true;
      checkReversePath = "loose";
    };

    nat.enable = true;
  };

  environment.systemPackages = with pkgs; [
    net_snmp
    tcpdump
    traceroute
    python-custom
  ];

  # programs & services
  programs.mtr.enable = true;
}
