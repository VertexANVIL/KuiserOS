{ config, lib, pkgs, name, utils, ... }:

with lib;

let
    inherit (utils.router) resolvePeers;

    eidolon = config.services.eidolon;
    cfg = eidolon.router;

    # maps peer types to templates
    TEMPLATE_TYPE_MAP = {
        downstream = "downstreams";
        upstream = "peers";
        peer = "peers";
        ix = "peers";
        internal = "eid_ibgp";
    };

    # maps peer types to filter function prefixes
    FILTER_TYPE_MAP = {
        downstream = "downstream";
        upstream = "transit";
        peer = "peer";
        ix = "ix";
        internal = "ibgp";
    };

    # Builds filters for a singular BIRD BGP neighbor.
    # Takes in the peer, the neighbor, the filter type, and protocol (v4/v6)
    buildPeerNeighborBlock = peer: neighbor: filterType: protocol:
        let
            protocolAttrs = peer.${"ip${protocol}"};

            # don't impose limits if this is true
            canPrefixLimit = ! elem peer.type [ "upstream" "internal" ];
        in
    ''ip${protocol} {
        ${optionalString (filterType != "ibgp") ''import filter { if ${
            if (filterType == "peer" || filterType == "downstream") then 
            ''${filterType}_import_${protocol}(${toString peer.asn})'' else 
            ''${filterType}_import_${protocol}()''
        } then accept; else reject; };''}
        ${
            (optionalString (canPrefixLimit && (protocolAttrs ? maxPrefix)) "import limit ${toString protocolAttrs.maxPrefix} action disable;")
        }
    };'';

    # Takes in peer data and the protocol (v4/v6)
    # and builds a BIRD "protocol" entry for BGP
    buildPeerProtocol = data: protocol:
        let
            addrs = if protocol == "v4" then data.neighbor.v4addrs else data.neighbor.v6addrs;
        in
        utils.imapAttrsToList (i: n: v:
        let name = if i == 0 then "bgp_${data.peerName}_${protocol}" else
            "bgp_${data.peerName}_${protocol}_${toString i}";
        in
        ''
        protocol bgp ${name} from ${data.template}_${protocol} {
            ${let peer = [
                ''neighbor ${n} as ${toString v.asn};''

                (optionalString (data.neighbor ? multihop) "multihop ${toString data.neighbor.multihop};")

                (utils.optionalList (data.peer.internal) [
                    (optionalString cfg.reflector "rr client;")
                ])

                (buildPeerNeighborBlock data.peer data.neighbor data.filterType protocol)
            ]; in (builtins.concatStringsSep "\n" (utils.filterListNonEmpty (flatten peer)))}
        };
        '') addrs;

    # Takes in a resolved peer entry and builds both protocols for it
    buildPeer = peer: let
        neighbor = peer.neighbor;
        hasAnyProto = v: let p = "v${toString v}"; in
            (utils.attrCount neighbor."${p}addrs" > 0) && (elem p peer.protocols);
        
        data = rec {
            inherit peer neighbor;
            hasv4 = hasAnyProto 4;
            hasv6 = hasAnyProto 6;

            # map the template and filter type on the Nix expression to our BIRD filter names
            template = TEMPLATE_TYPE_MAP.${peer.type};
            filterType = FILTER_TYPE_MAP.${peer.type};

            peerAsn = if peer.internal then "OWN_AS" else toString peer.asn;
            peerName = "${peer.type}_${peer.name}";
        };
        in assert (assertMsg (data.hasv4 || data.hasv6) "failed to resolve any addresses for neighbor ${data.neighbor.name}");
        # finally build both v4 and v6 protocols for the peer
        [
            (optionalString data.hasv4 (buildPeerProtocol data "v4"))
            (optionalString data.hasv6 (buildPeerProtocol data "v6"))
        ];

    staticRouteDefaults = {
        via = null;
        interface = null;
        prefsrc = null;
        blackhole = false;
        unreachable = false;
    };

    # Builds static routes for BIRD
    buildStaticRoutes = routes: v:
    concatStringsSep "\n" (forEach routes (addr: (
    let
        prefsrc = if (addr.prefsrc != null && addr.prefsrc == "@underlay") then (utils.underlayAddr eidolon.region name v).address else null;
        routeStr = utils.addrToString addr;
    in
        if addr.blackhole then
            "route ${routeStr} blackhole;"
        else if addr.unreachable then
            "route ${routeStr} unreachable;"
        else concatStrings [
            "route ${routeStr}"
            (optionalString (addr.via != null) " via ${addr.via}")
            (optionalString (addr.interface != null) " via \"${addr.interface}\"")
            (optionalString (prefsrc != null) " { krt_prefsrc = ${prefsrc}; }") ";"
        ]
    )));

    # Takes in address entries and builds
    # a BIRD static route block
    buildMasterExports = block: v: let
        defaults = staticRouteDefaults;

        # start with our static routes
        fullRoutes = block.routes.static ++

        # add one default unreachable route for every network of ours
        (map (route: defaults // {
            inherit (route) address prefixLength;
            unreachable = true;
        }) block.networks) ++

        # add our default route
        (optional (block.default != null) (defaults // {
            address = if (v == 6) then "::0" else "0.0.0.0"; prefixLength = 0;
            via = block.default;
            prefsrc = "@underlay";
        }));
    in buildStaticRoutes fullRoutes v;

    # Builds a BIRD network set from a list of address blocks
    buildNetworkSet = addr: v: let
        addrStr = concatStringsSep ", " (map (x: "${utils.addrToString x}+") addr);
    in "[ ${addrStr} ]";

    v4main = cfg.ipv4.addrs.primary;
    v6main = cfg.ipv6.addrs.primary;

    ourPeer = utils.internalBgpPeers.${eidolon.network};
    birdConf = ''
        ###   Generated by Nix; do not edit.
        ###   Router: ${config.networking.hostName}.${config.networking.domain}
        ###   Network: ${eidolon.network}

        ### Variables ###
        ${optionalString (v4main != null) "define OWN_IP4 = ${v4main.address};"}
        ${optionalString (v6main != null) "define OWN_IP6 = ${v6main.address};"}

        router id ${cfg.routerId};
        attribute int ibgprt;

        watchdog warning 5s;
        watchdog timeout 30s;
        
        ### Tables ###
        ${builtins.readFile ./tables.conf}

        ### Definitions ###
        define OWN_AS = ${toString cfg.asn};
        define OWN_NET_SET = ${buildNetworkSet cfg.ipv4.networks 4};
        define OWN_NET_SET_V6 = ${buildNetworkSet cfg.ipv6.networks 6};
        define RPKI_SERVER = ::1;

        ${builtins.readFile ./martians.conf}

        ### Filters ###
        ${builtins.readFile ./filters.conf}

        # Defines static routes to export to IGP
        protocol static interior_static_v4 {
            ipv4 { table interior4; };
            ${buildStaticRoutes cfg.ipv4.routes.igp 4}
        }

        protocol static interior_static_v6 {
            ipv6 { table interior6; };
            ${buildStaticRoutes cfg.ipv6.routes.igp 6}
        }

        # Defines static routes to export to EGP
        protocol static exterior_static_v4 {
            ipv4 { table exterior4; };
            ${buildStaticRoutes cfg.ipv4.routes.egp 4}
        }

        protocol static exterior_static_v6 {
            ipv6 { table exterior6; };
            ${buildStaticRoutes cfg.ipv6.routes.egp 6}
        }

        # Defines static routes we import directly into master
        protocol static master_static_v4 {
            ipv4 {
                table master4;
                import filter master_imports_v4;
            };
            
            ${buildMasterExports cfg.ipv4 4}
        }

        protocol static master_static_v6 {
            ipv6 {
                table master6;
                import filter master_imports_v6;
            };
            
            ${buildMasterExports cfg.ipv6 6}
        }

        ### FIB/RIB ###
        protocol device {
            scan time 10;
        }

        protocol direct {
            ipv4;
            ipv6;
        }

        # Export our routes to the kernel
        protocol kernel kernel4 {
            persist;
            graceful restart;
            scan time 20;

            ipv4 {
                table master4;
                import none;
                export filter {
                    if source = RTS_DEVICE then reject;
                    
                    ${optionalString (v4main != null) ''
                    # we want to set custom prefsrc for injected statics
                    if !defined(krt_prefsrc) then {
                        krt_prefsrc = OWN_IP4;
                    }
                    ''}
                    
                    accept;
                };
            };
        }

        protocol kernel kernel6 {
            persist;
            graceful restart;
            scan time 20;

            ipv6 {
                table master6;
                import none;
                export filter {
                    if source = RTS_DEVICE then reject;

                    ${optionalString (v6main != null) ''
                    # we want to set custom prefsrc for injected statics
                    if !defined(krt_prefsrc) then {
                        krt_prefsrc = OWN_IP6;
                    }
                    ''}
                    
                    accept;
                };
            };
        }

        ${builtins.readFile ./rib_interior.conf}
        ${builtins.readFile ./rib_exterior.conf}

        ### Peers ###
        ${concatStrings (flatten (map buildPeer resolvePeers))}

        ### Piping ###
        ${builtins.readFile ./pipes.conf};

        ### Extra ###
        ${cfg.impl.bird.extraConfig}
    '';
in {
    options = {
        services.eidolon.router.impl.bird = {
            extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = "Additional configuration to append.";
            };
        };
    };

    config = mkIf (cfg.enable && cfg.implementation == "bird") {
        # enable libssh support so we can use RPKI
        nixpkgs.config.packageOverrides = pkgs: {
            bird2 = pkgs.bird2.overrideAttrs (attrs: {
                #nativeBuildInputs = with pkgs; [ flex bison autoreconfHook ];
                buildInputs = attrs.buildInputs ++ [ pkgs.libssh ];
                configureFlags = attrs.configureFlags ++ [ "--enable-libssh" ];

                # override to use master version of bird
                # src = pkgs.fetchgit {
                #    url = "https://gitlab.labs.nic.cz/labs/bird.git";
                #    rev = "82937b465b3a50bdcb00eff0b7aa6acb3fc21772";
                #    sha256 = "0gv5rwnkwjdgk5iww4rb6m5a96fllmz3fak4s2w5kiljwmag0lad";
                # };
            });
        };

        services.bird2.enable = true;
        services.bird2.config = birdConf;
    };
}