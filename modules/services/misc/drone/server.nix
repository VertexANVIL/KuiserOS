{ config, pkgs, lib, ... }:

with lib;

let
    cfg = config.services.drone;

    droneWrapper = pkgs.writeShellScriptBin "drone-wrapper" ''
        export DRONE_RPC_SECRET=$(head -n1 /var/run/keys/drone)
        export DRONE_GITHUB_CLIENT_SECRET=$(head -n1 /var/run/keys/drone-github)
        export DRONE_GITEA_CLIENT_SECRET=$(head -n1 /var/run/keys/drone-gitea)
        export GODEBUG=netdns=go
        /bin/drone-server "$@"
    '';

    droneImage = with pkgs; dockerTools.pullImage {
        imageName = "drone/drone";
        imageDigest = "sha256:5ef6acfe9618f092dfaffe390d66cda420f28a7ac6ef84eccaa4d73a06c33966";
        sha256 = "05cpidqb5qiyhplhn64032f9m0xmfqr9444jylbacgrln3wy7r6z";
        finalImageName = "drone/drone";
        finalImageTag = "latest";
    };

    droneWrapperImage = with pkgs; dockerTools.buildImage {
        name = "drone-nix-wrapper";
        tag = "latest";

        fromImage = droneImage;
        contents = droneWrapper;
        config = {
            Cmd = [ "/bin/drone-wrapper" ];
        };
    };
in
{
    options.services.drone = {
        enable = mkEnableOption "Drone";

        github = {
            client = mkOption {
                type = types.str;
            };

            secretFile = mkOption {
                type = types.nullOr types.path;
            };
        };

        gitea = {
            client = mkOption {
                type = types.str;
            };

            secretFile = mkOption {
                type = types.nullOr types.path;
            };

            host = mkOption {
                type = types.str;
            };
        };

        host = mkOption {
            type = types.str;
        };

        proto = mkOption {
            type = types.str;
            default = "https";
        };

        secretFile = mkOption {
            type = types.nullOr types.path;
        };
    };

    config = mkIf cfg.enable {
        virtualisation.oci-containers.containers.drone = {
            image = "drone-nix-wrapper";
            imageFile = droneWrapperImage;
            ports = [ "8083:8080" ];

            # bind the keys into the container
            volumes = [
                "drone-server-data:/var/lib/drone"
                "${cfg.secretFile}:/var/run/keys/drone:ro"
                "${cfg.github.secretFile}:/var/run/keys/drone-github:ro"
                "${cfg.gitea.secretFile}:/var/run/keys/drone-gitea:ro"
            ];

            environment = {
                #DRONE_GITHUB_CLIENT_ID = cfg.github.client;

                DRONE_GITEA_SERVER = cfg.gitea.host;
                DRONE_GITEA_CLIENT_ID = cfg.gitea.client;

                DRONE_SERVER_HOST = cfg.host;
                DRONE_SERVER_PROTO = cfg.proto;

                DRONE_REGISTRATION_CLOSED = "false";
                #DRONE_LOGS_DEBUG = "true";
            };
        };
    };
}