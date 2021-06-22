{ lib, ... }: let
    inherit (lib) mkDefault;
in {
    # Default dynamically generated NixOS configuration for all hosts
    globalDefaults = { inputs, pkgs, name }:
    { config, ... }: let
        inherit (inputs) self home nixos unstable;
    in {
        nix.nixPath = [
            # "nixos=${nixos}" TODO: actually need this?
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

    # Special configuration for generating ISO images for installation
    isoConfig = { self, fullHostConfig }:
    { config, modulesPath, ... }@args: {
        imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal-new-kernel.nix" ];

        # avoid unwanted systemd service startups
        # all strings in disabledModules get appended to modulesPath
        # so convert each to list which can be coerced to string
        disabledModules = map lib.singleton (args.suites.allProfiles or [ ]);

        nix.registry = lib.mapAttrs (n: v: { flake = v; }) self.inputs;

        isoImage = {
            contents = [{
                source = self;
                target = "/arnix/";
            }];

            storeContents = [
                self.devShell.${config.nixpkgs.system}

                # include also closures that are "switched off" by the
                # above profile filter on the local config attribute
                fullHostConfig.system.build.toplevel
            ];

            # isoBaseName = "arnix-" + profileName;
        };

        # still pull in tools of deactivated profiles
        environment.systemPackages = fullHostConfig.environment.systemPackages;

        # confilcts with networking.wireless which might be slightly
        # more useful on a stick
        networking.networkmanager.enable = lib.mkForce false;

        # confilcts with networking.wireless
        networking.wireless.iwd.enable = lib.mkForce false;

        # Set up a link-local boostrap network
        # See also: https://github.com/NixOS/nixpkgs/issues/75515#issuecomment-571661659
        networking = {
            networking.usePredictableInterfaceNames = lib.mkForce true; # so prefix matching works
            networking.useNetworkd = lib.mkForce true;
            networking.useDHCP = lib.mkForce false;
            networking.dhcpcd.enable = lib.mkForce false;
        };

        systemd.network = {
            # https://www.freedesktop.org/software/systemd/man/systemd.network.html
            networks."boostrap-link-local" = {

            matchConfig = {
                Name = "en* wl* ww*";
            };

            networkConfig = {
                Description = "Link-local host bootstrap network";
                MulticastDNS = true;
                LinkLocalAddressing = "ipv6";
                DHCP = "yes";
            };

            address = [
                # fall back well-known link-local for situations where MulticastDNS is not available
                "fe80::47" # 47: n=14 i=9 x=24; n+i+x
            ];

            extraConfig = ''
                # Unique, yet stable. Based off the MAC address.
                IPv6LinkLocalAddressGenerationMode = "eui64"
            '';
            };
        };
    };
}