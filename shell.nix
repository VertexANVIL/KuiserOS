{ pkgs }:

let
    # tools to push Vault approles
    pushHostApproles = pkgs.writeScriptBin "push-host-vault-keys" (builtins.readFile ./tools/push-host-vault-keys.py);
in {
    nativeBuildInputs = (with pkgs; [
        python3 consul-template
    ]) ++ (with pkgs.python38Packages; [
        hvac paramiko Fabric
    ]) ++ [
        pushHostApproles
    ];
}
