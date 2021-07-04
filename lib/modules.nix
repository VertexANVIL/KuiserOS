{ lib, ... }: let
    inherit (lib) mkDefault;
in {
    # Default dynamically generated NixOS configuration for all hosts
    globalDefaults = { inputs, pkgs, name }:
    { config, ... }: let
        inherit (inputs) self home nixos unstable;
    in {
        nix.nixPath = [
            "nixpkgs=${nixos}"
            "unstable=${unstable}"
        ];

        nix.registry = {
            nixos.flake = nixos;
            nixpkgs.flake = nixos;
        };

        # set up system hostname
        networking.hostName = mkDefault name;
        deployment.targetHost = with config; mkDefault "${networking.hostName}.${networking.domain}";

        # always enable firmware by defaukt
        hardware.enableRedistributableFirmware = mkDefault true;

        # use flake revision
        system.configurationRevision = lib.mkIf (self ? rev) self.rev;

        # TODO: doesn't go here?
        nixpkgs = { inherit pkgs; };
    };

    # Default home-manager configuration
    hmDefaults = { specialArgs, modules }: {
        config = { # TODO: conditional enable, don't need for server profiles
            home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                extraSpecialArgs = specialArgs;
                sharedModules = modules;
            };
        };
    };
}