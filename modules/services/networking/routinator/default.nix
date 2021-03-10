{ config, lib, pkgs, ... }:

with lib;

let
    cfg = config.services.routinator;
in
{
    options = {
        services.routinator = {
            enable = mkOption {
                type = types.bool;
                default = false;
            };
        };
    };

    config = mkIf cfg.enable {
        systemd.services.init-routinator-tals = {
            description = "Create and download RPKI TALs for Routinator.";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig.Type = "oneshot";
            script = let dockercli = "${config.virtualisation.docker.package}/bin/docker";
            in
            ''
                check=$(${dockercli} volume ls | grep "routinator-tals" || true)
                if [ -z "$check" ]; then
                    ${dockercli} volume create routinator-tals
                    ${dockercli} run --rm -v routinator-tals:/home/routinator/.rpki-cache/tals \
    nlnetlabs/routinator init -f --accept-arin-rpa
                else
                    echo "skipping: TALs already loaded"
                fi
            '';
        };

        virtualisation.oci-containers.containers.routinator = {
            image = "nlnetlabs/routinator";
            ports = [ "3323:3323" "9556:9556" ];
            volumes = [ "routinator-tals:/home/routinator/.rpki-cache/tals" ];
            #extraDockerOptions = [ "--network=host" ];
        };

        # services.openssh.extraConfig = ''
        #     Subsystem rpki-rtr /bin/nc 127.0.0.1 3323
        #     Match Group rpki
        #         ChrootDirectory %h
        #         X11Forwarding no
        #         AllowTcpForwarding no
        #         ForceCommand rpki-rtr
        # '';
    };
}