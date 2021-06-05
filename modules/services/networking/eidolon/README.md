# Eidolon RIS

Eidolon RIS is a Routing Infrastructure Service framework built on NixOS and Colemena.

It provides:
- A fully meshed routing solution built on top of BIRD, supporting IGP and EGP protocols alike
- A flexible tunnel system with current support for GRE and WireGuard
- NAT64 via Tayga (bring your own DNS64 server!)

## Example

This is an example of the configuration of a single router node, 

```nix
services.eidolon = {
    # Enable Eidolon. Disabling this will unconfigure the node.
    enable = true;

    # The logical network identifier.
    network = "foobar";

    # The region identifier in the network.
    region = "lon2";

    # The interface to use for management and tunnel traffic.
    underlay = "ens18";

    router = {
        # Enables the router part of Eidolon.
        enable = true;

        # Configures this node as a route reflector.
        reflector = true;

        # Configures BGP peers.
        peers = [
            "bgp://upstream/ifog"
            "bgp://internal/fra1"
            "bgp://internal/stir1"
        ];

        # Configures the primary IPv4 and IPv6 addresses of this node.
        ipv4.addrs.primary = { address = "185.167.182.4"; prefixLength = 30; };
        ipv6.addrs.primary = { address = "2a10:4a80:3::1"; prefixLength = 48; };

        # Configures BGP peer definitions.
        # It's recommended to import these from a shared set of files.
        defs.peers = {
            ifog = {
                asn = 34927;
                types = [ "upstream" ];
                
                regions = { 
                    fra1 = {
                        v4addrs = "193.148.249.1";
                        v6addrs = "2a0c:9a40:1::1";
                    };

                    lon2 = {
                        v4addrs = "45.134.88.1";
                        v6addrs = "2a0c:9a40:1031::1";
                    };
                };
            };
        };
    };

    tunnel = {
        # Configures our peers.
        peers = [
            { endpoint = "@fra1"; v4addr = "10.2.0.3/31"; }
        ];
    };
};
```
