{ config, pkgs, lib, resources, deploymentName, name, ... }:

with lib;
let
    cfg = config.services.vault-agent;
    roleName = let prefix = "machines.${deploymentName}"; in
        if cfg.autoAuth.methods.appRole.addMachine then "${prefix}.${name}" else prefix;

    configFile = pkgs.writeText "vault-agent.hcl" ''
        #exit_after_auth = true
        #pid_file = "./pidfile"

        auto_auth {
            ${optionalString cfg.autoAuth.methods.appRole.enable ''
            method "approle" {
                config = {
                    role_id_file_path = "/var/run/keys/vault-approle-role-id"
                    secret_id_file_path = "/var/run/keys/vault-approle-secret-id"
                    #secret_id_response_wrapping_path = "auth/approle/role/${roleName}/secret-id"
                    remove_secret_id_file_after_reading = false
                }
            }
            ''}

            ${optionalString cfg.autoAuth.sinks.file.enable ''
            sink "file" {
                config = {
                    path = "${cfg.autoAuth.sinks.file.path}"
                }
            }
            ''}
        }

        ${optionalString cfg.cache.enable ''
        cache {
            use_auto_auth_token = ${toString cfg.cache.useAutoAuthToken}
        }
        ''}

        vault {
            address = "${cfg.address}"
            ${if (cfg.caCertFile != null) then ''ca_cert = "${cfg.caCertFile}"'' else ''''}
        }

        ${concatStringsSep "\n" (forEach cfg.listeners (listener: ''
        listener "${listener.type}" {
            address = "${listener.address}"
            ${if (listener.tlsCertFile != null && listener.tlsKeyFile != null) then ''
            tls_cert_file = "${listener.tlsCertFile}"
            tls_key_file = "${listener.tlsKeyFile}"
            '' else ''
            tls_disable = true
            ''}
        }
        ''))}

        ${concatStringsSep "\n" (forEach cfg.templates (template: 
        
        let sourceFile = if template.sourceFile != null then template.sourceFile
            else pkgs.writeText "template.ctmpl" template.sourceText;
        in
        ''
        template {
            source = "${sourceFile}"
            destination = "${template.destFile}"

            ${optionalString (template.createDestDirs == false) ''
            create_dest_dirs = false
            ''}

            ${optionalString (template.command != null) ''
            command = "${template.command}"
            command_timeout = "${toString template.commandTimeout}s"
            ''}

            error_on_missing_key = true
            perms = "${template.perms}"

            ${optionalString template.backup ''
            backup = true
            ''}
            
            ${optionalString (template.sandboxPath != null) ''
            sandbox_path = "${template.sandboxPath}"
            ''}
        }
        ''))}

        ${cfg.extraConfig}
    '';

    listenerSubmodule = { ... }:
    { options = {
        type = mkOption {
            type = types.enum [ "tcp" "unix" ];
            default = "tcp";
            description = "Type of the listener to use";
        };

        address = mkOption {
            type = types.str;
            default = "127.0.0.1:8200";
            description = "Address of the listener to listen to";
        };

        tlsKeyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to the TLS private key";
        };

        tlsCertFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to the TLS certificate";
        };
    }; };

    templateSubmodule = { ... }:
    { options = {
        sourceFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "The source template to use, as a file.";
        };

        sourceText = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "The source template to use.";
        };

        destFile = mkOption {
            type = types.str;
            description = "The destination path to render the template.";
        };

        createDestDirs = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to create the destination directories automatically if they do not exist.";
        };

        command = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional command to run after the template is rendered.";
        };

        commandTimeout = mkOption {
            type = types.int;
            default = 30;
            description = "Maximum amount of time to wait for the optional command, in seconds.";
        };

        perms = mkOption {
            type = types.str;
            default = "0600";
            example = "0640";
            description = "The permissions to render the file.";
        };

        backup = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to back up the previously rendered template.";
        };

        sandboxPath = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Checks to ensure the path is within this path.";
        };
    }; };
in
rec {
    options = {
        services.vault-agent = {
            enable = mkEnableOption "Vault agent";

            package = mkOption {
                type = types.package;
                default = pkgs.vault;
                defaultText = "pkgs.vault";
                description = "This option specifies the vault package to use.";
            };

            address = mkOption {
                type = types.str;
                default = "http://127.0.0.1:8200";
                description = "Address of the Vault instance to connect to.";
            };

            caCertFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Path to the certificate authority to use to verify the Vault certificate.";
            };

            autoAuth = {
                methods = {
                    appRole = {
                        enable = mkEnableOption "AppRole";
                        roleName = mkOption {
                            type = types.str;
                            default = roleName;
                            description = "Name of the AppRole to use for authentication";
                        };

                        addMachine = mkOption {
                            type = types.bool;
                            default = false;
                            description = "If true, suffix the role name with the name of the machine.";
                        };
                    };
                };
                
                sinks = {
                    file = {
                        enable = mkEnableOption "File";
                        path = mkOption {
                            type = types.str;
                            description = "The destination path for the File sink";
                        };
                    };
                };
            };

            cache = {
                enable = mkEnableOption "Cache";
                useAutoAuthToken = mkOption {
                    type = types.either types.bool (types.enum [ "force" ]);
                    default = false;
                    description = "Whether to forward requests with the auto auth token";
                };
            };

            listeners = mkOption {
                type = types.listOf ( types.submodule listenerSubmodule );
                default = [];
                description = "List of listeners for the agent to create";
            };

            templates = mkOption {
                type = types.listOf ( types.submodule templateSubmodule );
                default = [];
                description = "List of templates for the agent to create";
            };

            storagePath = mkOption {
                type = types.path;
                default = "/var/lib/vault-agent";
                description = "Directory for persistent data";
            };

            extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = "Extra text appended to <filename>vault-agent.hcl</filename>.";
            };
        };
    };

    config = mkIf cfg.enable {
        #assertions = [{
        #    assertion = ((length (attrNames cfg.autoAuth.sinks)) > 0) || cfg.cache.useAutoAuthToken != false;
        #    message = ''At least one auto auth sink must be defined if useAutoAuthToken is disabled'';
        #}];

        users = {
            users.vault-agent = {
                name = "vault-agent";
                group = "vault-agent";
                description = "Vault agent user";
                extraGroups = [ "keys" ];
            };

            groups.vault-agent = {};
        };

        systemd.services.vault-agent = {
            description = "Vault agent daemon";

            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ] ++ optionals cfg.autoAuth.methods.appRole.enable [
                "vault-approle-role-id-key.service"
                "vault-approle-secret-id-key.service"
            ];

            serviceConfig = {
                User = "vault-agent";
                Group = "vault-agent";
                ExecStart = "${cfg.package}/bin/vault agent -config ${configFile}";
                ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectSystem = "full";
                ProtectHome = "read-only";
                NoNewPrivileges = true;
                KillSignal = "SIGINT";
                TimeoutStopSec = "30s";
                Restart = "always";
                StartLimitInterval = "60s";
                StartLimitBurst = 3;
            };
        };

        deployment.keys.vault-approle-role-id = {
            keyCommand = [ "arc-get-vault-approle-role-id" roleName ];
            user = "vault-agent";
            group = "vault-agent";
        };

        deployment.keys.vault-approle-secret-id = {
            keyCommand = [ "arc-get-vault-approle-role-secret" roleName ];
            user = "vault-agent";
            group = "vault-agent";
        };
    };
}