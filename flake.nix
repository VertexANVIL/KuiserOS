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

        home = {
           url = "github:nix-community/home-manager/master";
           inputs.nixpkgs.follows = "nixpkgs";
        };

        deploy = {
            url = "github:serokell/deploy-rs";
            inputs = {
                nixpkgs.follows = "nixpkgs";
                utils.follows = "flake-utils";
            };
        };
    };

    outputs = inputs@{ nixos, flake-utils, ... }: let
        lib = import ./lib { inherit nixos flake-utils; baseInputs = inputs; };
    in (lib.mkRootArnixRepo { inputs = inputs // { inherit lib; }; });
}