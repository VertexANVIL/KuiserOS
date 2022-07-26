{
  description = "ARbitrary NixOS base configurations";

  inputs = {
    # conventional nixos channels
    nixpkgs.url = "nixpkgs/nixos-22.05";
    unstable.url = "github:ArctarusLimited/nixpkgs";

    # official flakes
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # our flakes
    xnlib = {
      url = "github:ArctarusLimited/xnlib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # community flakes
    nur.url = "github:nix-community/NUR";
    nixlib.url = "github:nix-community/nixpkgs.lib";
    impermanence.url = "github:nix-community/impermanence";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixlib.follows = "nixlib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # third party
    flake-compat = {
      flake = false;
      url = "github:edolstra/flake-compat";
    };

    flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
    colmena.url = "github:zhaofengli/colmena";

    home = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bud = {
      url = "github:divnix/bud";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixos, ... }:
    let
      lib = import ./lib {
        baseInputs = inputs;
      };

      inherit (lib.kuiser) mkBaseRepo;
    in
    mkBaseRepo {
      inherit inputs;
    };
}
