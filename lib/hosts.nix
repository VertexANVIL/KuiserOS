{ inputs
, extern
, lib
, pkgs
, root
, system
, base
, flat
, ... }:

let
    inherit (inputs) self home nixos unstable;
    inherit (self) users profiles;

    inherit (lib) nixosSystem;
    inherit (lib.arnix) recImportFiles recImportDirs defaultImports;
    inherit (builtins) attrValues removeAttrs;

    config = hostName: let
        # flat = colmena/nixops style, one folder per host in the root
        # non-flat = devos style, one .nix file per host in the hosts folder
        hostFile = root + (if flat then "/${hostName}" else "/hosts/${hostName}.nix");
    in nixosSystem {
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
                    nixos.flake = nixos;
                    nixpkgs.flake = nixos;
                };

                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
            };

            deploy = { config, ... }: {
                options.deployment = with lib; {
                    targetHost = mkOption {
                        default = with config.networking; mkDefault "${hostName}.${domain}";
                        description = "The fully qualified host name of the node to deploy to.";
                    };
                };
            };

            # import the actual host configuration (i.e. kuiser.nix) at the top level
            local.require = [ hostFile ];

            modOverrides = { config, overrideModulesPath, ... }: let
                overrides = import ../overrides;
                inherit (overrides) modules disabledModules;
            in {
                disabledModules = modules ++ disabledModules;
                imports = map (path: "${overrideModulesPath}/${path}") modules;
            };

            # Everything in `./modules/list.nix`.
            flakeModules = attrValues (removeAttrs self.nixosModules [ "profiles" ]);
        in flakeModules ++ [
            core global deploy base local modOverrides
        ] ++ extern.modules;
    };

    # make attrs for each possible host
    hosts = if flat then recImportDirs {
        dir = root;
        _import = config;
    } else recImportFiles {
        dir = root + "/hosts";
        _import = config; 
    };
in hosts
