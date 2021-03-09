{ config, lib, pkgs, ... }:
with lib;
let
    cfg = config.services.barrier;
    configFile = pkgs.writeText "barrier.sgc" cfg.config;
in
{
    options.services.barrier = {
        enable = mkOption {
            type = types.bool;
            default = false;
        };

        name = mkOption {
            type = types.str;
        };

        config = mkOption {
            type = types.lines;
        };
    };

    config = mkIf cfg.enable {
        systemd.user.services.barrier = {
            Install = {
                WantedBy = [ "graphical-session.target" ];
            };

            Unit = {
                After = [ "graphical-session-pre.target" ];
                PartOf = [ "graphical-session.target" ];
            };

            Service = {
                ExecStart = "${pkgs.barrier}/bin/barriers --no-daemon --debug INFO --name ${cfg.name} --enable-crypto --address :24800 --config ${configFile}";
                ExecStop = "${pkgs.procps}/bin/pkill barriers";
                Restart = "always";
            };
        };
    };
}