{ config, pkgs, lib, ... }:
with lib;
let
    mkVaultKeyCmd = path: field: [
        "vault" "kv" "get" "-field=${field}" "secret/${path}"
    ];
in
{
    options.deployment.vault-keys = mkOption {
        default = {};
        type = types.attrs;
    };

    config.deployment.keys = (flip mapAttrs config.deployment.vault-keys (_: key:
    (filterAttrs (n: v: n != "vault") key ) // {
        keyCommand = mkVaultKeyCmd key.vault.path key.vault.field;
    }));
}
