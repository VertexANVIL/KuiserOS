{ inputs
, extern
, overrides
, lib
, pkgs
, root
, system
, base
, flat
, ... }:

let
    inherit (inputs) self home nixos unstable;
    inherit (self._internal) repos;

    inherit (lib) nixosSystem mkDefault;
    inherit (lib.arnix) recImportFiles recImportDirs defaultImports
        recursiveMerge recursiveMergeAttrsWith;
    inherit (builtins) attrValues removeAttrs;

    config = name: let
        # flat = hosts live in top-level rather than in "hosts" folder
        hostFile = root + (if flat then "/${name}" else "/hosts/${name}");
    in nixosSystem {
        inherit system;

        # note: failing to add imports in here
        # WILL result in an obscure "infinite recursion" error!!
        specialArgs = extern.specialArgs // {
            inherit lib repos name nodes root;
        };

        modules = let
            # merge down core profiles from all repos
            core.require = (recursiveMergeAttrsWith (
                a: b: recursiveMerge [ a b ]
            ) (attrValues repos)).profiles.core.defaults;

            global = { config, ... }: {
                networking.hostName = mkDefault name;
                hardware.enableRedistributableFirmware = mkDefault true;

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

                # auto setup for Colmena
                deployment.targetHost = with config; mkDefault "${networking.hostName}.${networking.domain}";

                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
            };

            # import the actual host configuration (i.e. kuiser.nix) at the top level
            local.require = [ hostFile ];

            modOverrides = { config, overrideModulesPath, ... }: let
                inherit (overrides) modules disabledModules;
            in {
                disabledModules = modules ++ disabledModules;
                imports = map (path: "${overrideModulesPath}/${path}") modules;
            };

            # Everything in `./modules/list.nix`.
            flakeModules = attrValues (removeAttrs self.nixosModules [ "profiles" ]);
        in flakeModules ++ [
            core global base local modOverrides
        ] ++ extern.modules;
    };

    # make attrs for each possible host
    nodes = recImportDirs {
        dir = if flat then root else root + "/hosts";
        _import = config;
    };
in nodes
