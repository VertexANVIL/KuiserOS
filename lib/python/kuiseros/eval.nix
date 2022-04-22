{ lib, nodes }: let
    inherit (lib) filterAttrs mapAttrs unique tryEval';
    inherit (builtins) isAttrs isFunction removeAttrs;
in
    (mapAttrs (n: v: let
        cfg = v.config;
        appRole = v.config.services.vault-agent.autoAuth.methods.appRole;
    in {
        # TODO: should we be using a seperate attribute for this?
        dns = cfg.deployment.targetHost;
        eidolon = tryEval' cfg.services.eidolon;

        vault = {
            appRole = {
                inherit (appRole) enable name;
                policies = appRole.policies;
            };

            keys = mapAttrs (k: v:
                # remove stuff we don't need
                removeAttrs v [ "dependency" "postRenew" "sinks" ]
            ) cfg.reflection.vault-keys;
        };
    }) nodes)
