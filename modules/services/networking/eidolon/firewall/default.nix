{ config, lib, utils, ... }:

with lib;

let
    eidolon = config.services.eidolon;
    cfg = config.services.eidolon.firewall;

    rules = let
        mkChain = type: chain: ''
            ip46tables -D ${type} -j ${chain} 2> /dev/null || true
            ip46tables -F ${chain} 2> /dev/null || true
            ip46tables -X ${chain} 2> /dev/null || true
            ip46tables -N ${chain}

            # add new rules
            ip46tables -A ${type} -j ${chain}
        '';
    in ''
        # ==================================
        # Local Firewall - Input Rules
        # ==================================
        ${mkChain "INPUT" "eidolon-fw"}

        ${cfg.input}

        # ==================================
        # Border Firewall - Forwarding Rules
        # ==================================
        ${mkChain "FORWARD" "eidolon-bfw"}

        # always clamp TCP packet MSS to path MTU
        ip46tables -A eidolon-bfw -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

        # conntrack existing packets
        ip46tables -A eidolon-bfw -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        # allow ICMPv4 echo requests
        iptables -A eidolon-bfw -p icmp --icmp-type echo-request -j ACCEPT

        # allow all ICMPv6 requests except redirect & node info
        ip6tables -A eidolon-bfw -p icmpv6 --icmpv6-type redirect -j DROP
        ip6tables -A eidolon-bfw -p icmpv6 --icmpv6-type 139 -j DROP

        ip6tables -A eidolon-bfw -p icmpv6 -j ACCEPT

        ${cfg.forward}

        # ==================================
        # End of preconfigured rules
        # ==================================
    '';
in {
    options = {
        services.eidolon.firewall = {
            input = mkOption {
                type = types.lines;
                default = "";
                description = "Rules to be added to the input rule section";
            };

            forward = mkOption {
                type = types.lines;
                default = "";
                description = "Rules to be added to the forwarding rule section";
            };
        };
    };

    config = mkIf eidolon.enable {
        networking.firewall.extraCommands = rules;
    };
}