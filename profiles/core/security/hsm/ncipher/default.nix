{ pkgs, ... }:
{
    environment.sessionVariables = {
        "NFAST_HOME" = "/opt/nfast";
    };

    system.activationScripts.linkNfastOpt = {
        text = ''
            if [ ! -d /opt ]; then
                mkdir /opt
                chmod 0755 /opt
            fi

            ln -sfT "${pkgs.codesafe}/opt/nfast" "/opt/nfast"
        '';
    };
}
