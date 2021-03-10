{
    description = "ARbitrary NixOS base configurations";

    inputs = {
        # conventional nixos channels
        nixos.url = "nixpkgs/release-20.09";
        nixpkgs.url = "nixpkgs/release-20.09";
        unstable.url = "nixpkgs";

        flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
        nixos-hardware.url = "github:NixOS/nixos-hardware/master";
        nur.url = "github:nix-community/NUR";

        #home-manager = {
        #    url = "github:nix-community/home-manager/master";
        #    inputs.nixpkgs.follows = "nixpkgs";
        #};
    };

    outputs = inputs@{ nixos, flake-utils, ... }: let
        lib = import ./lib { inherit nixos flake-utils; };
    in (lib.mkRootArnixRepo inputs) // { inherit lib; };
}