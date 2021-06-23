{
    description = "ARbitrary NixOS base configurations";

    inputs = {
        # conventional nixos channels
        nixos.url = "nixpkgs/release-21.05";
        nixpkgs.url = "nixpkgs/release-21.05";
        unstable.url = "nixpkgs";

        # official flakes
        nixos-hardware.url = "github:NixOS/nixos-hardware/master";

        # community flakes
        nur.url = "github:nix-community/NUR";
        impermanence.url = "github:nix-community/impermanence";
        nixos-generators.url = "github:nix-community/nixos-generators";

        # third party
        flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
        colmena.url = "github:ArctarusLimited/colmena/feat/flake-support";

        home = {
           url = "github:nix-community/home-manager/release-21.05";
           inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs@{ self, unstable, ... }: let
        lib = import ./lib {
            inherit (unstable) lib;
            baseInputs = inputs;
        };
    in (lib.mkRootArnixRepo { inputs = inputs // { inherit lib; }; });
}