{ config, lib, utils, regions, ... }:

with lib;

let
    inherit (lib.arnix) defaultAttrs;
    inherit (utils) addrOpts addrsToOpts addrToString;
    inherit (utils.router) routeOpts resolvePeers;

    eidolon = config.services.eidolon;
    cfg = eidolon.router;

    versionOpts = v: {
        options = {
            addrs = {
                primary = mkOption {
                    type = with types; nullOr (submodule (addrOpts v));
                    default = null;
                    description = "Routable IPv${toString v} address of this machine that will be assigned to the dummy0 interface.";
                };

                anycast = mkOption {
                    type = with types; listOf str;
                    default = [];
                    description = "Anycast IPv${toString v} addresses of this machine that will be assigned to the dummy0 interface.";
                };
            };

            default = mkOption {
                type = types.nullOr types.str;
                default = let n = config.networking; in if (v == 6)
                    then defaultAttrs n.defaultGateway6 null (x: x.address)
                    else defaultAttrs n.defaultGateway null (x: x.address);
                description = "Gateway for the IPv${toString v} default route. Defaults to the system default gateway.";
            };

            networks = mkOption {
                type = with types; listOf (submodule (addrOpts v));
                default = [];
                description = "List of IPv${toString v} networks that are our own. These will be unreachable by default.";
            };

            routes = {
                igp = mkOption {
                    type = with types; listOf (submodule (routeOpts v));
                    default = [];
                    description = ''
                        List of IPv${toString v} static routes, which will be exported to IGP peers.
                    '';
                };

                egp = mkOption {
                    type = with types; listOf (submodule (routeOpts v));
                    default = [];
                    description = ''
                        List of IPv${toString v} static routes, which will be exported to EGP peers.
                    '';
                };

                static = mkOption {
                    type = with types; listOf (submodule (routeOpts v));
                    default = [];
                    description = ''
                        List of IPv${toString v} static routes, which will go directly into the FIB.
                    '';
                };
            };
        };
    };
in {
    imports = [ ./bird ./nat64 ];

    options = {
        services.eidolon.router = {
            enable = mkEnableOption "Eidolon RIS Router";

            implementation = mkOption {
                type = types.str;
                default = "bird";
                description = "Routing implementation to use.";
            };

            routerId = mkOption {
                type = types.str;
                default = cfg.ipv4.addrs.primary.address;
            };

            # all internal clients of this router will be 
            # route reflector clients unless forced otherwise
            reflector = mkOption {
                type = types.bool;
                default = false;
            };

            peers = mkOption {
                type = types.listOf (types.either types.str types.attrs);
                default = [];
                description = "List of either peer URIs or peer override attribute sets.";
            };

            asn = mkOption {
                type = types.int;
                description = "Our autonomous system number.";
            };

            ipv4 = mkOption {
                type = types.submodule (versionOpts 4);
            };

            ipv6 = mkOption {
                type = types.submodule (versionOpts 6);
            };

            defs = {
                peers = mkOption {
                    type = types.attrs;
                    default = {};
                    description = "Attribute set of peer definitions.";
                };
            };
        };
    };

    config = mkMerge [{
        _module.args.utils.router = utils // (import ./utils.nix {
            inherit config lib regions utils;
        });
    } (mkIf (eidolon.enable && cfg.enable) {
        networking = {
            interfaces.dummy0 = {
                # set the dummy as primary since it will be routed
                primary = true;

                # set up dummy interface addresses
                ipv4.addresses = with cfg.ipv4.addrs; (optional (primary != null) primary) ++ (addrsToOpts anycast 4);
                ipv6.addresses = with cfg.ipv6.addrs; (optional (primary != null) primary) ++ (addrsToOpts anycast 6);
            };
        };

        # TODO: Below peer firewall rules should be deduplicated
        # If we have more than one peer using v4/v6 hybrid we need to use this way
        services.eidolon.firewall.input = ''
            # BGP peers
            ${concatStrings (flatten 
                (forEach resolvePeers (peer:
                    mapAttrsToList (n: _: ''
                        iptables -A eidolon-fw -s ${n} -p tcp --dport 179 -j ACCEPT
                    '') peer.neighbor.v4addrs ++
                    mapAttrsToList (n: _: ''
                        ip6tables -A eidolon-fw -s ${n} -p tcp --dport 179 -j ACCEPT
                    '') peer.neighbor.v6addrs
            )))}
        '';
    })];
}