{ arnix
, extern
, home
, lib
, nixos
, unstable
, pkgs
, root
, self
, system
, ...
}:

let
    inherit (lib) nixosSystem;
    inherit (lib.arnix) recImport defaultImports;
    inherit (builtins) attrValues removeAttrs;

    config = hostName: nixosSystem {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit lib; # ????????????
            inherit (self) users profiles;
        };

        modules = let
            core = ../profiles/core;

            global = {
                networking.hostName = hostName;
                hardware.enableRedistributableFirmware = lib.mkDefault true;

                home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                };

                nix.nixPath = [
                    "unstable=${unstable}"
                    "nixpkgs=${nixos}"
                    "nixos=${nixos}"
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

            # Everything in `./modules/list.nix`.
            flakeModules = attrValues (removeAttrs self.nixosModules [ "profiles" ]);
        in flakeModules ++ [
            core global local modOverrides
        ] ++ extern.modules;
    };

    # make attrs for each possible host
    hosts = recImport {
        dir = root + "/hosts";
        _import = config;
    };
in hosts
