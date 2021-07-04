{ pkgs }:

let
    # tools to push Vault approles
    pushHostApproles = pkgs.writeScriptBin "push-host-vault-keys" (builtins.readFile ./../tools/push-host-vault-keys.py);
in {
    nativeBuildInputs = (with pkgs; [
        python3 consul-template
        nixos-generators
    ]) ++ (with pkgs.python38Packages; [
        hvac paramiko Fabric
        
        # not supported on x86_64-darwin, breaks `nix flake check`
        # tpm2-pytss
    ]) ++ [
        pushHostApproles
    ];
}
