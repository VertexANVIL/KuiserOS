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

        colmena.url = "github:ArctarusLimited/colmena/feat/flake-support";
        impermanence.url = "github:nix-community/impermanence";

        home = {
           url = "github:nix-community/home-manager/release-20.09";
           inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs@{ nixos, flake-utils, ... }: let
        lib = import ./lib { inherit nixos flake-utils; baseInputs = inputs; };
    in (lib.mkRootArnixRepo { inputs = inputs // { inherit lib; }; });
}