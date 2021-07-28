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
            "nixos-config=${self}/compat/nixos"
            "home-manager=${home}"
        ];

        nix.registry = {
            kuiser.flake = self;
            nixos.flake = nixos;
            unstable.flake = unstable;
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
    hmDefaults = { sharedModules, extraSpecialArgs }: {
        config = {
            home-manager = {
                inherit sharedModules extraSpecialArgs;

                useGlobalPkgs = true;
                useUserPackages = true;
            };
        };
    };
}