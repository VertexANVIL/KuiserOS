{ config, lib, pkgs, nodes, ... }:

with lib;

let
    cfg = config.services.eidolon;
in {
    imports = [ ./firewall ./router ./tunnel ];

    options = {
        services.eidolon = {
            enable = mkEnableOption "Eidolon RIS";

            underlay = mkOption {
                type = with types; nullOr str;
                default = null;
            };

            network = mkOption {
                type = with types; nullOr str;
                default = null;
            };

            region = mkOption {
                type = with types; nullOr str;
                default = null;
            };
        };
    };

    config = {
        _module.args = let
            # regions is just nodes bucketised by services.eidolon.region
            regions = foldl' (prev: cur: let
                name = cur.config.services.eidolon.region;
                list = if hasAttr name prev then prev.${name} else [];
            in prev // {
                ${name} = list ++ [cur];
            }) {} nodes;
        in {
            inherit regions;
            tools = (import ./utils.nix {
                inherit config lib regions;
            });
        };
    };
}
