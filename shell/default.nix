{ pkgs, root }:
{
    nativeBuildInputs = (with pkgs; [
        python3 nixos-generators
        consul-template inix-helper
    ]) ++ (with pkgs.python3Packages; [
        black hvac icmplib tabulate paramiko Fabric

        # not supported on x86_64-darwin, breaks `nix flake check`
        # tpm2-pytss
    ]);
}