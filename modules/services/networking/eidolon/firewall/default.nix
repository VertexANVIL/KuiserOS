{ config, lib, ... }:

with lib;

let
  eidolon = config.services.eidolon;
  cfg = config.services.eidolon.firewall;

  rules =
    let
      mkChain = type: chain: ''
        ip46tables -D ${type} -j ${chain} 2> /dev/null || true
        ip46tables -F ${chain} 2> /dev/null || true
        ip46tables -X ${chain} 2> /dev/null || true
        ip46tables -N ${chain}

        # add new rules
        ip46tables -A ${type} -j ${chain}
      '';
    in
    ''
      # ==================================
      # Local Firewall - Input Rules
      # ==================================
      ${mkChain "INPUT" "eidolon-fw"}

      ${cfg.input}

      # ==================================
      # Border Firewall - Forwarding Rules
      # ==================================
      ${mkChain "FORWARD" "eidolon-bfw"}

      # clamp TCP packet MSS to path MTU
      ip46tables -A eidolon-bfw -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

      ${cfg.forward}

      # ==================================
      # End of preconfigured rules
      # ==================================
    '';
in
{
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
