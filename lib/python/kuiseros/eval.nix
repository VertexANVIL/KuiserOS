{ lib, nodes, ... }:
let
  inherit (lib) filterAttrs mapAttrs mapAttrs' unique nameValuePair;
  inherit (builtins) isAttrs isFunction removeAttrs tryEval;

  # Like `tryEval`, but recursive.
  # copied from xnlib because colmena stuff :/
  tryEval' = set:
    let
      recurse = s: mapAttrs
        (n: v:
          let
            eval = tryEval v;
            value = if eval.success then eval.value else null;
          in
          if isAttrs value
          then recurse value
          else value)
        s;
    in
    recurse set;
in
(mapAttrs'
  (n: v:
  let
    cfg = v.config;
    fqdn = "${cfg.networking.hostName}.${cfg.networking.domain}";
    appRole = v.config.services.vault-agent.autoAuth.methods.appRole;
  in
  nameValuePair fqdn {
    # TODO: should we be using a seperate attribute for this?
    dns = cfg.deployment.targetHost;
    eidolon = tryEval' cfg.services.eidolon;

    vault = {
      appRole = {
        inherit (appRole) enable name;
        policies = appRole.policies;
      };

      keys = mapAttrs
        (k: v:
          # remove stuff we don't need
          removeAttrs v [ "dependency" "postRenew" "sinks" ]
        )
        cfg.reflection.vault-keys;
    };
  })
  nodes)
