{
    description = "ARbitrary NixOS base configurations";

    inputs = {
        # conventional nixos channels
        nixos.url = "nixpkgs/release-21.05";
        nixpkgs.url = "nixpkgs/release-21.05";
        unstable.url = "nixpkgs";

        flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
        nixos-hardware.url = "github:NixOS/nixos-hardware/master";
        nur.url = "github:nix-community/NUR";

        colmena.url = "github:ArctarusLimited/colmena/feat/flake-support";
        impermanence.url = "github:nix-community/impermanence";

        home = {
           url = "github:nix-community/home-manager/release-21.05";
           inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs@{ self, nixos, ... }: let
        lib = import ./lib {
            inherit (nixos) lib;
            baseInputs = inputs;
        };
    in (lib.mkRootArnixRepo { inputs = inputs // { inherit lib; }; });
}