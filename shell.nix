{ pkgs }:

let
    # tools to push Vault approles
    pushHostApproles = pkgs.writeScriptBin "push-host-approles" (builtins.readFile ./tools/push-host-approles.py);
in {
    nativeBuildInputs = (with pkgs; [
        python3
    ]) ++ (with pkgs.python38Packages; [
        hvac paramiko Fabric
    ]) ++ [
        pushHostApproles
    ];
}
