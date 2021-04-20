{ config, pkgs, lib, ... }:

with lib;
let
    formatConsulParams = attrs: (concatStringsSep " " (
        flip mapAttrsToList attrs (key: value: ("\"${key}=${value}\""))
    ));

    backendToDefName = backend: if (backend == "kv") then "secret" else backend;

    createConsulTemplates = key:
    let
        # figure out what backend we're going to use
        backendFilter = filterAttrs (n: v: v != null) key.backends;
        backendCount = length (attrNames backendFilter);
        backendName = if (backendCount > 0) then (head (attrNames backendFilter)) else null;
        backend = if (backendCount > 0) then (head (attrValues backendFilter)) else null;

        type = backendName;
        name = if (key.backendName != null) then key.backendName else backendToDefName backendName;

        # info shared between all templates
        keyInfo = if type == "kv" then {
            addr = "${name}/data/${backend.path}";
            params = {};
        } else if type == "pki" then {
            addr = "${name}/issue/${backend.policy}";
            params = { "common_name" = backend.commonName; };
        } else null;

        # template outputs for each type
        keyTmpls = if key.template != null then [{
            body = key.template;
        }] else if type == "kv" then [{
            body = ["{{ .Data.data | toJSON }}"];
        }] else if type == "pki" then (
            let
                # repr of the certificate
                certLines = [
                    "{{- .Data.certificate }}"
                ] ++ (optional backend.fullChain [
                    "{{- if index .Data \"ca_chain\" }}"
                    "{{- range $cert := .Data.ca_chain }}\n{{ $cert }}{{ end }}"
                    "{{- end }}"
                ]);

                # repr of the private key
                keyLines = [
                    "{{- .Data.private_key }}"
                ];
            in

            # whether to split or bundle them together
            if backend.bundle then [{
                body = certLines ++ keyLines;
            }] else [{
                suffix = "public";
                body = certLines;
            } {
                suffix = "private";
                body = keyLines;
            }]
        ) else null;

    # final template generator
    in
    assert (assertMsg (backendCount == 1)) "vault key ${key.name}: exactly one backend must be specified";

    forEach keyTmpls (template: rec {
        suffix = if template ? suffix then template.suffix else null;
        id = if (suffix != null) then "${key.name}-${template.suffix}" else key.name;
        
        text = concatStringsSep "\n" (flatten [
            "{{- with secret \"${keyInfo.addr}\" ${formatConsulParams keyInfo.params} }}"
            template.body
            "{{- end }}"
        ]);
    });

    backendTypes = {
        kv = types.submodule ({ config, ... }: {
            options = {
                path = mkOption {
                    type = types.str;
                    description = "Path to the key/value key in Vault.";
                };

                field = mkOption {
                    type = types.str;
                    description = "Default key/value field to use.";
                };
            };
        });

        pki = types.submodule ({ config, ... }: {
            options = {
                policy = mkOption {
                    type = types.str;
                    description = "Name of the PKI policy in Vault.";
                };

                bundle = mkOption {
                    default = false;
                    type = types.bool;
                    description = "Whether to bundle both the certificate and private key into one file.";
                };

                commonName = mkOption {
                    type = types.str;
                    description = "Common name of the certificate.";
                };

                fullChain = mkOption {
                    default = true;
                    type = types.bool;
                    description = "Includes the full certificate chain.";
                };
            };
        });
    };

    sinkType = types.submodule ({ config, name, ... }: {
        options = {
            name = mkOption {
                default = name;
                type = types.str;
                description = "Name of the destination file. Default is to use the sink name.";
            };

            user = mkOption {
                default = "root";
                type = types.str;
                description = "The user which will be the owner of the key file.";
            };

            group = mkOption {
                default = "root";
                type = types.str;
                description = "The group that will be set for the key file.";
            };

            permissions = mkOption {
                default = "0600";
                example = "0640";
                type = types.str;
                description = ''
                    The default permissions to set for the key file, needs to be in the
                    format accepted by ``chmod(1)``.
                '';
            };

            kv = {
                field = mkOption {
                    default = null;
                    type = types.nullOr types.str;
                    description = "The key/value field that this sink should pull from.";
                };
            };
        };
    });

    keyType = types.submodule ({ config, name, ... }: {
        options = {
            name = mkOption {
                example = "secret-123";
                default = name;
                type = types.str;
                description = "The name of the key.";
            };

            template = mkOption {
                default = null;
                type = types.nullOr types.lines;
                description = "Specifies a custom HCL template to render the key. Overrides built-in sink renderers.";
            };

            backends = {
                kv = mkOption {
                    type = types.nullOr backendTypes.kv;
                    default = null;
                };

                pki = mkOption {
                    type = types.nullOr backendTypes.pki;
                    default = null;
                };
            };

            backendName = mkOption {
                default = null;
                example = "pki_int";
                type = types.nullOr types.str;
                description = "The name of the Vault backend. Default is to use the default name for the backend type.";
            };

            # JM TODO: We need to get vault-agent to reload whenever this changes, how?
            sinks = mkOption {
                default = { "${name}" = {}; };
                type = types.attrsOf sinkType;
                description = "List of sink configurations that describe how to render this key to a file. If not set, the key name will be used.";
            };

            postRenew = {
                command = mkOption {
                    default = "";
                    type = types.str;
                    description = "Optional command to run after the key is renewed.";
                };

                units = mkOption {
                    default = [];
                    example = "[ \"nginx\" ]";
                    type = types.listOf types.str;
                    description = "Dependent systemd units for the key.";
                };
            };
        };
    });

    # build all the vault agent templates for a key
    buildAgentTemplates = key:
    let
        defaults = {
            createDestDirs = false;
            sandboxPath = "/run/vault-keys";
        };
    in (forEach key.templates (template: ({
        sourceFile = pkgs.writeText "vault-key-${template.id}.ctmpl" template.text;
        destFile = "/run/vault-keys/.${template.id}.tmp";
    } // defaults)));

    # builds the final set of keys
    finalKeys = (flip mapAttrs config.security.vault-keys (_: key: key // { templates = createConsulTemplates key; }));
in
{
    options.security.vault-keys = mkOption {
        default = {};
        type = types.attrsOf keyType;
    };

    config = mkIf (length (attrNames config.security.vault-keys) > 0) {
        services.vault-agent.templates = flatten (flip mapAttrsToList finalKeys (_: key: buildAgentTemplates key));

        users.users = (listToAttrs (flatten (flip mapAttrsToList finalKeys (_: key:
           (flip mapAttrsToList (flip filterAttrs key.sinks (_: sink: sink.user != "root")) (_: sink: (nameValuePair sink.user { extraGroups = [ "keys" ]; })))
        ))));

        systemd.paths =
        # create a path watcher for every template key
        (listToAttrs (flatten (flip mapAttrsToList finalKeys (_: key:
            (forEach key.templates (template: { name = "vault-key-${template.id}"; value = {
                wantedBy = [ "multi-user.target" ];
                pathConfig = let path = "/run/vault-keys/.${template.id}.tmp"; in {
                    PathModified = path;
                    Unit = "vault-key-${template.id}.service";
                };
            }; }))
        ))));

        systemd.services =
        # create a service for every template key
        (listToAttrs (flatten (flip mapAttrsToList finalKeys (_: key:
            let checkScript = (pkgs.writeText "vault-key-${key.name}-check.sh" ''
                set -euo pipefail

                # check to see if we have all dependencies yet
                ${concatStrings (forEach key.templates (template: ''
                    if ! [[ -e "/run/vault-keys/.${template.id}.done" ]]; then exit 0; fi
                ''))}

                # cleanup .done files
                ${concatStrings (forEach key.templates (template: ''
                    rm "/run/vault-keys/.${template.id}.done"
                ''))}

                # finally render the keys
                ${concatStringsSep "\n" (flatten (
                let
                    prefix = "/run/vault-keys";
                    soletmpl = head key.templates;
                in
                [(flip mapAttrsToList key.sinks (_: sink: let
                    buildStandaloneKey = let
                        dest = "${prefix}/${sink.name}"; 
                    in [
                        "cp '${prefix}/.${soletmpl.id}.tmp' '${dest}'"
                        "chmod ${sink.permissions} '${dest}'"
                        "chown '${sink.user}:${sink.group}' '${dest}'"
                    ];
                in
                    # we're always standalone if the parent key is overriding with a custom template
                    if key.template != null then buildStandaloneKey

                    # composite keys (suffixed with template suffix)
                    else if (length key.templates) > 1 then (forEach key.templates (template: let
                        dest = "${prefix}/${sink.name}-${template.suffix}";
                    in [
                        "cp '${prefix}/.${template.id}.tmp' '${dest}'"
                        "chmod ${sink.permissions} '${dest}'"
                        "chown '${sink.user}:${sink.group}' '${dest}'"
                    ]))

                    # special for key/value keys (file per field)
                    else if (key.backends.kv != null) then let
                        dest = "${prefix}/${sink.name}";
                    in [
                        "cat '${prefix}/.${soletmpl.id}.tmp' | ${pkgs.jq}/bin/jq -j -r '.[\"${sink.kv.field}\"]' > '${dest}'"
                        "chmod ${sink.permissions} '${dest}'"
                        "chown '${sink.user}:${sink.group}' '${dest}'"
                    ]
                        
                    # fallback to regular
                    else buildStandaloneKey))

                    # remove the temporary files
                    (forEach key.templates (template: "rm '${prefix}/.${template.id}.tmp'"))
                ]))}

                # restart the post service
                systemctl restart vault-key-${key.name}-post.service
            ''); in
            (forEach key.templates (template: { name = "vault-key-${template.id}"; value = {
                serviceConfig.Type = "oneshot";
                script = let
                    prefix = "/run/vault-keys";
                    tmp = "${prefix}/.${template.id}.tmp";
                    path = "${prefix}/${template.id}";
                in ''
                    set -euo pipefail
                    if ! [[ -e "${tmp}" ]]; then exit 0; fi

                    touch "${prefix}/.${template.id}.done"
                    source ${checkScript}
                '';
            }; }))
        )))) //
        
        # create a service for every key that's activated after all templates complete
        (listToAttrs (flip mapAttrsToList finalKeys (_: key: { name = "vault-key-${key.name}-post"; value = 
        {
            before = key.postRenew.units;

            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };

            script = ''
                set -euo pipefail

                # perform actions on dependent units
                ${concatStrings (forEach key.postRenew.units (unit: (''
                    systemctl reload-or-restart ${unit} --no-block
                '')))}

                ${key.postRenew.command}
            '';
        }; }))) //
        
        # default systemd options
        {
            vault-agent.serviceConfig.ReadWritePaths = "/run/vault-keys";
        };

        system.activationScripts.vault-keys =
        let script = ''
            mkdir -p /run/vault-keys -m 0770
            chown root:keys /run/vault-keys
        '';
        in stringAfter [ "users" "groups" ] "source ${pkgs.writeText "setup-vault-keys.sh" script}";
    };
}