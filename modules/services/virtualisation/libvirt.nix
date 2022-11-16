{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.virtualisation.libvirtd;

  boolToZeroOne = x: if x then "1" else "0";

  aclString = with lib.strings;
    concatMapStringsSep ''
      ,
    ''
      escapeNixString
      cfg.deviceACL;
in
{
  options.virtualisation.libvirtd = {
    deviceACL = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    clearEmulationCapabilities = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    # Add qemu-libvirtd to the input group if required
    users.users."qemu-libvirtd" = {
      extraGroups = optionals (!cfg.qemu.runAsRoot) [ "kvm" "input" ];
      isSystemUser = true;
    };

    virtualisation.libvirtd.qemu.verbatimConfig = ''
      clear_emulation_capabilities = ${
        boolToZeroOne cfg.clearEmulationCapabilities
      }
      cgroup_device_acl = [
        ${aclString}
      ]
    '';
  };
}
