{
    description = "ARbitrary NixOS base configurations";

    inputs = {
        # conventional nixos channels
        nixos.url = "https://nixos.org/channels/nixos-20.09/nixexprs.tar.xz";
        nixpkgs.url = "https://nixos.org/channels/nixos-20.09/nixexprs.tar.xz";
        unstable.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";

        flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
        nixos-hardware.url = "github:NixOS/nixos-hardware/master";

        #home-manager = {
        #    url = "github:nix-community/home-manager/master";
        #    inputs.nixpkgs.follows = "nixpkgs";
        #};
    };

    outputs = inputs@{ nixos, ... }: let
        lib = import ./lib { inherit nixos; };
    in (lib.mkRootArnixRepo inputs) // { inherit lib; };
}