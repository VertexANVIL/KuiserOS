{ config, pkgs, lib, ... }:

let
    inherit (lib) mkDefault mkEnableOption mkForce mkIf mkMerge mkOption;
    inherit (lib) concatStringsSep literalExample mapAttrsToList optional optionals optionalString types;

    cfg = config.services.keycloak-alt;
in
{
    options.services.keycloak-alt = {
        enable = mkEnableOption "Keycloak";

        url = mkOption {
            type = types.str;
        };
    };

    config = mkIf cfg.enable {
        virtualisation.oci-containers.containers.keycloak = {
            image = "jboss/keycloak";
            ports = [ "8082:8080" ];
            volumes = [ "keycloak-db:/opt/jboss/keycloak/standalone/data" ];

            cmd = [ "-Dkeycloak.migration.strategy=IGNORE_EXISTING" ];
            environment = {
                KEYCLOAK_FRONTEND_URL = cfg.url;

                # enable this to create an admin user
                #KEYCLOAK_USER = "admin";
                #KEYCLOAK_PASSWORD = "X#W{TOqr1=dhh4cUT?B.";
            };
        };
    };
}