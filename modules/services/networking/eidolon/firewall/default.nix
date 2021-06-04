{ config, lib, utils, ... }:

with lib;

let
    cfg = config.services.eidolon.firewall;
    router = config.services.eidolon.router;
    tunnel = config.services.eidolon.tunnel;
    underlay = config.services.eidolon.underlay;

    # old stuff
    # routinator = config.services.routinator;
    # # TODO: allow routinator from everywhere
    #    ${optionalString routinator.enable ''
    #        ip46tables -A eidolon-fw -p tcp --match multiport --dports 3323,9556 -j ACCEPT
    #    ''}

    # TODO: Below peer firewall rules should be deduplicated
    # If we have more than one peer using v4/v6 hybrid we need to use this way
    fwdata = ''
        # ==================================
        # Local Firewall - Input Rules
        # ==================================
        ip46tables -D INPUT -j eidolon-fw 2> /dev/null || true
        ip46tables -F eidolon-fw 2> /dev/null || true
        ip46tables -X eidolon-fw 2> /dev/null || true
        ip46tables -N eidolon-fw

        # add new rules
        ip46tables -A INPUT -j eidolon-fw

        # allow only for actual tunnel interfaces
        ${if (length tunnel.peers) == 0 then "" else "ip46tables -A eidolon-fw -i ${underlay} -p gre -j ACCEPT"}
        ${concatStrings (forEach utils.resolvedTunnelPeers (peer: ''
            ip46tables -A eidolon-fw -i ${peer.interface} -p ospfigp -j ACCEPT
        ''))}

        # BGP peers
        ${concatStrings (flatten 
            (forEach utils.resolvePeers (peer:
                mapAttrsToList (n: _: ''
                    iptables -A eidolon-fw -s ${n} -p tcp --dport 179 -j ACCEPT
                '') peer.neighbor.v4addrs ++
                mapAttrsToList (n: _: ''
                    ip6tables -A eidolon-fw -s ${n} -p tcp --dport 179 -j ACCEPT
                '') peer.neighbor.v6addrs
        )))}

        # ==================================
        # Border Firewall - Forwarding Rules
        # ==================================
        ip46tables -D FORWARD -j eidolon-bfw 2> /dev/null || true
        ip46tables -F eidolon-bfw 2> /dev/null || true
        ip46tables -X eidolon-bfw 2> /dev/null || true
        ip46tables -N eidolon-bfw

        ip46tables -A FORWARD -j eidolon-bfw

        # always clamp TCP packet MSS to path MTU
        ip46tables -A eidolon-bfw -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

        # conntrack existing packets
        ip46tables -A eidolon-bfw -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        # allow unrestricted traffic from our own networks
        ${concatStringsSep "\n" (flatten [
            (map (addr: "iptables -A eidolon-bfw -s ${utils.addrToString addr} -j ACCEPT") router.ipv4.networks)
            (map (addr: "ip6tables -A eidolon-bfw -s ${utils.addrToString addr} -j ACCEPT") router.ipv6.networks)
        ])}
        
        # allow unrestricted traffic out to Eidolon peers
        # AZ: this is so that traffic from hosts inside ACN can go out from one node and come back in from another without issues
        # TODO: If we had multiple Eidolon nodes peered with an ACN network, this probably wouldn't work.
        # TODO: In that case the traffic on the second node might pick its local return tunnel, and get blocked at conntrack. We could:
        # (a) move the firewall back onto the ACN routers (allow any from our networks?)
        # (b) setup a conntrack sync service between the peers
        ${concatStringsSep "\n" (forEach (filter (x: hasPrefix "eid" x.interface) utils.resolvedTunnelPeers) (peer: ''
            ip46tables -A eidolon-bfw -o ${peer.interface} -j ACCEPT
        ''))}

        # explicitly allow access to and from the ANI peers of this router
        # this should be able to be removed after I (hopefully) renumber them, so we can allow the entire address block
        ${concatStringsSep "\n" (remove null (forEach utils.resolvedTunnelPeers (peer: 
            if peer.node != null then let
                addr = peer.node.config.services.eidolon.router.ipv6.addrs.primary;
            in ''
                ip6tables -A eidolon-bfw -d ${addr.address} -j ACCEPT
            '' else null
        )))}

        # allow ICMPv4 echo requests
        iptables -A eidolon-bfw -p icmp --icmp-type echo-request -j ACCEPT

        # allow all ICMPv6 requests except redirect & node info
        ip6tables -A eidolon-bfw -p icmpv6 --icmpv6-type redirect -j DROP
        ip6tables -A eidolon-bfw -p icmpv6 --icmpv6-type 139 -j DROP

        ip6tables -A eidolon-bfw -p icmpv6 -j ACCEPT

        # always permit ACN subnets, because this is a customer network and most likely on HCP which does firewalling itself
        ip6tables -A eidolon-bfw -d 2a10:4a80:400::/38 -j ACCEPT

        # drop any other traffic not allowed by any above rule going into our internal network
        ip6tables -A eidolon-bfw -d 2a10:4a80::/32 -j DROP

        # ==================================
        # End of preconfigured rules
        # ==================================

        ${cfg.extraRules}
    '';

    #${if router.enable then concatStrings (mapAttrsToList (address:
    #    ''iptables -A eidolon-fw -p tcp --dport 179 -s ${address} -j ACCEPT''
    #) router.peers) else ""}

in {
    options = {
        services.eidolon.firewall = {
            enable = mkEnableOption "Eidolon RIS Firewall";

            name = mkOption {
                type = types.str;
                default = "";
            };

            extraRules = mkOption {
                type = types.str;
                default = "";
            };
        };
    };

    config = mkIf cfg.enable {
        networking.firewall.extraCommands = fwdata;
    };
}