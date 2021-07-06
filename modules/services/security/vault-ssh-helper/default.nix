{ config, pkgs, lib, resources, deploymentName, name, ... }:

with lib;
let
    cfg = config.services.vault-ssh-helper;

    configFile = pkgs.writeText "vault-ssh-agent.hcl" ''
        vault_addr = "${cfg.address}"
        ssh_mount_point = "${cfg.mountPoint}"

        ${optionalString (cfg.caCertFile != null) ''
        ca_cert = "${cfg.caCertFile}"
        ''}

        tls_skip_verify = ${if cfg.tlsSkipVerify then "true" else "false"}

        allowed_roles = "${concatStringsSep "," cfg.allowedRoles}"

        ${optionalString ((length cfg.allowedCidrs) > 0) ''
        allowed_cidr_list = "${concatStringsSep "," cfg.allowedCidrs}"
        ''}
    '';
in
{
    options = {
        services.vault-ssh-helper = {
            enable = mkEnableOption "Vault SSH helper";

            package = mkOption {
                type = types.package;
                default = pkgs.vault-ssh-helper;
                defaultText = "pkgs.vault-ssh-helper";
                description = "This option specifies the ssh helper package to use.";
            };

            address = mkOption {
                type = types.str;
                default = "http://127.0.0.1:8200";
                description = "Address of the Vault instance to connect to.";
            };

            mountPoint = mkOption {
                type = types.str;
                default = "ssh";
                description = "Mount point of the SSH backend in Vault.";
            };

            caCertFile = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Path to the CA cert file";
            };

            tlsSkipVerify = mkOption {
                type = types.bool;
                default = false;
                description = "Skip TLS verification";
            };

            allowedRoles = mkOption {
                type = types.listOf types.str;
                default = ["*"];
                description = "List of Vault roles that are allowed to log in";
            };

            allowedCidrs = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "List of CIDR blocks that are allowed to log in";
            };
        };
    };

    config = mkIf cfg.enable {
        # dummied out for now
        #security.pam.vault-ssh.enable = true;
        #security.pam.vault-ssh.configFile = configFile;

        #security.pam.services.sshd.vaultSshAuth = true;
    };
}