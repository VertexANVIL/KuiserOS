{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.security.fde;

  # 64-character key is randomly generated locally
  # then sealed against one or more protectors
  # and encrypted with specified GPG key for recovery purposes

  # on initial run, pick up a "seed key" instead of generating one
  # should probably be in /var somewhere, with root perms

  # generate initial key with:
  # openssl rand -base64 32
  protectorType = types.submodule ({ config, ... }: {
    options = {
      tpm = {
        enable = mkEnableOption "TPM";

        pcrs = mkOption {
          default = [ 0 1 2 3 4 8 9 12 ];
          type = types.listOf types.int;
          description = ''
            List of PCR registers.

            0 = BIOS
            1 = BIOS Configuration
            2 = Option ROMs
            3 = Option ROMs Configuration
            4 = MBR
            5 = MBR Configuration
            6 = State transitions and wake events
            7 = Platform manufacturer specific measurements
            8-15 = Static operating system
            16 = Debug
            23 = Application support
          '';
        };
      };

      vault = {
        enable = mkEnableOption "Vault";

        path = mkOption {
          example = "transit/keys/foobar";
          type = types.str;
          description = "Path to the transit key.";
        };
      };
    };
  });

  targetType = types.submodule ({ config, ... }: {
    options = {
      protectors = mkOption {
        type = types.listOf types.str;
        description = "List of protectors to seal the VMK against.";
      };

      types = {
        zfs = mkOption { };
      };
    };
  });
in
{
  # Manages full-disk encryption
  options.security.fde = {
    protectors = mkOption {
      default = { };
      type = types.attrsOf protectorType;
      description = "Attributes of key protectors that may be referenced by targets.";
    };

    targets = mkOption {
      default = { };
      type = types.listOf targetType;
      description = "List of target volumes to encrypt.";
    };
  };
}
