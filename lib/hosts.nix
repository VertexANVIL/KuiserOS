{ inputs, extern, lib, pkgs, root, system, ... }:

let
    inherit (inputs) self arnix home nixos unstable;
    inherit (self) users profiles;

    inherit (lib) nixosSystem;
    inherit (lib.arnix) recImport defaultImports;
    inherit (builtins) attrValues removeAttrs;

    config = hostName: nixosSystem {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit lib hostName users profiles;
            deploymentName = "none"; # TODO for prod
        };

        modules = let
            core.require = profiles.core.defaults;

            global = {
                networking.hostName = hostName;
                hardware.enableRedistributableFirmware = lib.mkDefault true;

                home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                };

                nix.nixPath = [
                    "nixos=${nixos}"
                    "nixpkgs=${nixos}"
                    "unstable=${unstable}"
                ];

                nixpkgs = { inherit pkgs; };

                nix.registry = {
                    arnix.flake = arnix;
                    nixos.flake = nixos;
                    nixpkgs.flake = nixos;
                };

                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
            };

            # import the actual host configuration (i.e. kuiser.nix) at the top level
            local.require = [(root + "/hosts/${hostName}.nix")];

            modOverrides = { config, overrideModulesPath, ... }: let
                overrides = import ../overrides;
                inherit (overrides) modules disabledModules;
            in {
                disabledModules = modules ++ disabledModules;
                imports = map (path: "${overrideModulesPath}/${path}") modules;
            };

            # TODO: VERY TEMP!! HACK FIX
            temp = {
                options.deployment.keys = with lib; mkOption {
                    default = {};
                    type = types.attrs;
                };
            };

            # Everything in `./modules/list.nix`.
            flakeModules = attrValues (removeAttrs self.nixosModules [ "profiles" ]);
        in flakeModules ++ [
            core global local modOverrides temp
        ] ++ extern.modules;
    };

    # make attrs for each possible host
    hosts = recImport {
        dir = root + "/hosts";
        _import = config;
    };
in hosts
