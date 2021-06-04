{ config, lib, name, utils, ... }:

with lib;

let
    eidolon = config.services.eidolon;
    cfg = eidolon.tunnel;

    resolved = utils.resolvedTunnelPeers;

    providerTypes = {
        gre = types.submodule ({ config, ... }: {
            # todo
        });

        wireguard = types.submodule ({ config, ... }: {
            options = {
                allowedIPs = mkOption {
                    type = types.listOf types.str;
                    default = [ "0.0.0.0/0" "::/0" ];
                    description = "List of allowed IP addresses from the peer.";
                };

                presharedKey = mkOption {
                    type = types.nullOr types.str;
                    description = "The preshared key to use with the peer.";
                };

                publicKey = mkOption {
                    type = types.str;
                    description = "The public key to use with the peer.";
                };
            };
        });
    };

    peerType = types.submodule ({ config, ... }: {
        options = {
            interface = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "The interface name. Default is to autogenerate.";
            };

            endpoint = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "The address of the peer.";
            };

            port = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "The port used to connect to the peer. Only some providers use this.";        
            };

            providers = {
                gre = mkOption {
                    type = types.nullOr providerTypes.gre;
                    default = null;
                };

                wireguard = mkOption {
                    type = types.nullOr providerTypes.wireguard;
                    default = null;
                };
            };

            v4addr = mkOption {
                type = types.nullOr types.str;
                default = null;
            };
        };
    });

    preconf = (forEach resolved (peer:
    let
        providerFilter = filterAttrs (n: v: v != null) peer.providers;
        providerCount = utils.attrCount providerFilter;
        providerName = if (providerCount > 0) then (head (attrNames providerFilter)) else null;
        provider = if (providerCount > 0) then (head (attrValues providerFilter)) else null;
    in
        assert (assertMsg (providerCount <= 1)) "no more than one peer provider may be specified";

        # ==== WireGuard ====
        if (providerName == "wireguard") then 
        let port = if (peer.port != null) then peer.port else 51820; in
        {
            networking.wireguard.interfaces.${peer.interface}.peers = [{
                inherit (provider) allowedIPs presharedKey publicKey;
                endpoint = if (peer.endpoint != null) then "${peer.endpoint}:${toString port}" else null;
            }];
        }
        
        # ==== GRE ====
        # this is the fallback
        else
        {
            networking.localCommands = with peer; ''
                ip link show ${interface} > /dev/null 2>&1 && ip link delete ${interface}
                ip link add name ${interface} type ip6gre local ${cfg.address} remote ${endpoint} dev ${utils.underlay}
                ${optionalString (v4addr != null) ''ip address add ${v4addr} dev ${interface}''} 

                ip link set ${interface} multicast on
                ip link set ${interface} up
            '';
        }
    ));

    mkConfOpt = path: default: mkIf cfg.enable (mkMerge (forEach preconf (x: attrByPath path default x)));
    mkRouteEntry = peer: v: {
        address = peer.endpoint;
        prefixLength = if (v == 6) then 128 else 32;
        via = if (v == 6) then config.networking.defaultGateway6.address
            else config.networking.defaultGateway.address;
    };
in {
    options = {
        services.eidolon.tunnel = {
            enable = mkEnableOption "Eidolon RIS Tunnel";

            address = mkOption {
                type = types.str;
                default = (utils.underlayAddr eidolon.region name 6).address;
                description = "The address to use to connect. Defaults to the underlay address.";
            };

            peers = mkOption {
                type = types.listOf (types.either peerType types.str);
                default = [];
                description = "List of peers to connect to. Peers prefixed with @ will be resolved as machines in the Eidolon network.";
            };
        };
    };

    config.networking = mkMerge [(mkConfOpt ["networking"] {}) {
        interfaces.${utils.underlay} = {
            # create static routes in order to route tunnel traffic via the underlay interface
            # these routes are NOT managed via BIRD, in order to ensure we can still recover the router if BIRD crashes
            ipv4.routes = (forEach (filter (p: (p.endpoint != null) && !(utils.isIPv6 p.endpoint)) resolved) (p: mkRouteEntry p 4));
            ipv6.routes = (forEach (filter (p: (p.endpoint != null) && (utils.isIPv6 p.endpoint)) resolved) (p: mkRouteEntry p 6));
        };
    }];
}