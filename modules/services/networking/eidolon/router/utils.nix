{ config, lib, tools, ... }:

with lib;

let
    eidolon = config.services.eidolon;
    router = eidolon.router;

    routeOpts = v:
    assert v == 4 || v == 6;
    {
        options = {
            address = mkOption {
                type = types.str;
                default = null;
                description = "IPv${toString v} address of the network.";
            };

            prefixLength = mkOption {
                type = types.addCheck types.int (n: n >= 0 && n <= (if v == 4 then 32 else 128));
                description = ''
                Subnet mask of the network, specified as the number of
                bits in the prefix (<literal>${if v == 4 then "24" else "64"}</literal>).
                '';
            };

            via = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "IPv${toString v} address of the next hop.";
            };

            interface = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Interface of the next hop.";
            };

            prefsrc = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Preferred source address of the route.";
            };

            blackhole = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to mark the route as blackholed.";
            };

            unreachable = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to mark the route as unreachable.";
            };
        };
    };

    # normalises neighbor keys that accept multiple types to sets
    # examples:
    # [ "foo" "bar" ] = { "foo" = {} "bar" = {} }
    # "foobar" = { "foobar" = {} }
    neighborKeyToAttrs = (s: k: if (hasAttr k s) then
        let 
            val = s.${k};
        in
        (if builtins.isAttrs val then val else 
         if builtins.isList val then genAttrs val (x: { }) else 
         { ${val} = { }; })
    else { });

    # TODO:
    # unless transit, ix, or internal ignore all maxprefix lengths set in ipv4/ipv6 and also filter addrs by specified type!!

    # resolves a BGP peer from a string ident
    resolvePeerBgp = input: (
        let
            ident = input.uri;
            compParams = splitString "@" ident;

            protocols = if (length compParams >= 2) then
                let proto = elemAt compParams 1; in
                assert (assertMsg (elem proto [ "v4" "v6" ]) "invalid peer protocol; must be v4 or v6.");
                singleton proto
            else [ "v4" "v6" ];

            components = splitString "/" (head compParams);

            peerType = elemAt components 0;
            peerName = elemAt components 1;

            internal = peerType == "internal";

            # third parameter on a peer URI allows specifying the destination region of the peer
            # this is required for scenarios such as when the peer's region is only reachable over a tunnel interface
            peerRegion = if (length components >= 3) then elemAt components 2 else eidolon.region;

            # find peers that match the criteria
            peer = let
                # checks to ensure peerType is in types
                peerHasType = peerType: types: protocols:
                    if (elem peerType types) then true else
                    if length (filter (x: elem "${peerType}@${x}" types) protocols) > 0 then true else false;

                found = mapAttrsToList(_: x: x) (filterAttrs (name: peer:
                    # if set to internal, our peer name will be what we have as the network
                    (name == (if internal then eidolon.network else peerName)) && 
                    (peerHasType peerType peer.types protocols)
                ) router.defs.peers);
            in
                assert (assertMsg (length found == 1) "failed to resolve any BGP peers with the URI \"bgp://${ident}\"");
                head found;

            # if internal, we use the region specified in the URI instead of looking it up from the local host as it's over a tunnel
            # also note we're applying x to the neighbor object - this allows for overrides.
            neighborAttrs = (if internal then peer.regions.${peerName} else peer.regions.${peerRegion}) // input;

            # attrs to copy from the peer to the individual v4/v6 addresses, if they don't exist there
            # these are essentially just attributes that can differ from address to address, i.e. ASN
            neighborDefaultAttrs = [ "asn" ];
        in {
            asn = if hasAttr "asn" peer then peer.asn else null;
            type = peerType;
            name = peerName;

            ipv4 = if hasAttr "ipv4" peer then peer.ipv4 else {};
            ipv6 = if hasAttr "ipv6" peer then peer.ipv6 else {};

            protocols = protocols; # TODO: filter by enabled protocols
            internal = internal;

            neighbor = {
                # normalise the v4/v6 addrs and copy over default attrs from the peer to each address
                v4addrs = tools.defaultSetAttrs (neighborKeyToAttrs neighborAttrs "v4addrs") neighborDefaultAttrs peer;
                v6addrs = tools.defaultSetAttrs (neighborKeyToAttrs neighborAttrs "v6addrs") neighborDefaultAttrs peer;
            };
        }
    );

    # resolves all protocol peers
    resolvePeers = ((forEach router.peers (x:
        let
            peer = if (isAttrs x) then x
            else if (isString x) then { uri = x; }
            else null;    
        in

        assert peer != null;
        assert (assertMsg (hasPrefix "bgp://" peer.uri) "unsupported routing protocol for peer ${peer.uri}");
        resolvePeerBgp (peer // { uri = removePrefix "bgp://" peer.uri; })
    )));
in {
    inherit routeOpts resolvePeers;
}
