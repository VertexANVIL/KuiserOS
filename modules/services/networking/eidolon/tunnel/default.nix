{ config, lib, name, utils, regions ? {}, ... }:

with lib;

let
    eidolon = config.services.eidolon;
    cfg = eidolon.tunnel;

    resolved = (flip imap0 cfg.peers) (i: peer: peer // (
    let
        internal = (peer.endpoint != null) && (hasPrefix "@" peer.endpoint);

        # need to use a different prefix for inter-network links
        # as OSPF uses this to decide on enabled interfaces
        interfacePrefix = if internal then "eid" else "eic";
        interface = if (peer.interface != null) then peer.interface else "${interfacePrefix}${toString i}";

        regionName = removePrefix "@" peer.endpoint;

        node = if internal then
            assert (assertMsg (hasAttr regionName regions) "referenced region ${regionName} was not found!");
            regions.${regionName}.bdr1 # TODO: shouldn't rely on the default router being called "bdr1"
        else null;
    
        endpoint = if (peer.endpoint != null && node != null) then node.config.services.eidolon.tunnel.address else peer.endpoint;
    in
    {
        inherit interface endpoint node;
    }));

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
        f = filterAttrs (n: v: v != null) peer.providers;
        count = utils.attrCount f;
        name = if (count > 0) then (head (attrNames f)) else null;
        provider = if (count > 0) then (head (attrValues f)) else null;
    in
        assert (assertMsg (count <= 1)) "no more than one peer provider may be specified";

        # ==== WireGuard ====
        if (name == "wireguard") then 
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

    mkConfOpt = path: default: mkMerge (forEach preconf (x: attrByPath path default x));
    mkRouteEntry = peer: v: {
        address = peer.endpoint;
        prefixLength = if (v == 6) then 128 else 32;
        via = if (v == 6) then config.networking.defaultGateway6.address
            else config.networking.defaultGateway.address;
    };
in {
    options = {
        services.eidolon.tunnel = {
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

    config = mkIf eidolon.enable {
        networking = mkMerge [(mkConfOpt ["networking"] {}) {
            interfaces.${utils.underlay} = {
                # create static routes in order to route tunnel traffic via the underlay interface
                # these routes are NOT managed via BIRD, in order to ensure we can still recover the router if BIRD crashes
                ipv4.routes = (forEach (filter (p: (p.endpoint != null) && !(utils.isIPv6 p.endpoint)) resolved) (p: mkRouteEntry p 4));
                ipv6.routes = (forEach (filter (p: (p.endpoint != null) && (utils.isIPv6 p.endpoint)) resolved) (p: mkRouteEntry p 6));
            };
        }];

        services.eidolon.firewall = {
            input = ''
                # allow only for actual tunnel interfaces
                ${if (length cfg.peers) == 0 then "" else "ip46tables -A eidolon-fw -i ${eidolon.underlay} -p gre -j ACCEPT"}
                ${concatStrings (forEach resolved (peer: ''
                    ip46tables -A eidolon-fw -i ${peer.interface} -p ospfigp -j ACCEPT
                ''))}
            '';

            forward = ''
                # allow unrestricted traffic out to Eidolon peers
                # AZ: this is so that traffic from hosts inside ACN can go out from one node and come back in from another without issues
                # TODO: If we had multiple Eidolon nodes peered with an ACN network, this probably wouldn't work.
                # TODO: In that case the traffic on the second node might pick its local return tunnel, and get blocked at conntrack. We could:
                # (a) move the firewall back onto the ACN routers (allow any from our networks?)
                # (b) setup a conntrack sync service between the peers
                ${concatStringsSep "\n" (forEach (filter (x: hasPrefix "eid" x.interface) resolved) (peer: ''
                    ip46tables -A eidolon-bfw -o ${peer.interface} -j ACCEPT
                ''))}

                # explicitly allow access to and from the ANI peers of this router
                # this should be able to be removed after I (hopefully) renumber them, so we can allow the entire address block
                ${concatStringsSep "\n" (remove null (forEach resolved (peer: 
                    if peer.node != null then let
                        addr = peer.node.config.services.eidolon.router.ipv6.addrs.primary;
                    in ''
                        ip6tables -A eidolon-bfw -d ${addr.address} -j ACCEPT
                    '' else null
                )))}
            '';
        };
    };
}