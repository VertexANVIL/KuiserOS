{ pkgs, ... }:
{
    users = {
        users = {
            nfast = {
                group = "nfast";
                isSystemUser = true;
            };

            raserv = {
                group = "raserv";
                isSystemUser = true;
            };
        };

        groups = {
            nfast = {};
            raserv = {};
        };
    };

    environment.sessionVariables = {
        "NFAST_HOME" = "/opt/nfast";
    };

    system.activationScripts.linkNfastOpt = {
        text = ''
            if [ ! -d /opt ]; then
                mkdir /opt
                chmod 0755 /opt
            fi

            mkdir -p /opt/nfast
            chown nfast:nfast /opt/nfast
            chmod 0755 /opt/nfast

            mkdir -p /opt/nfast/sockets
            chown nfast:nfast /opt/nfast/sockets
            chmod 2775 /opt/nfast/sockets

            mkdir -p /opt/nfast/sockets/private
            chown nfast:nfast /opt/nfast/sockets/private
            chmod 2750 /opt/nfast/sockets/private

            linkDir()
            {
                ln -sfT "${pkgs.secworld}/opt/nfast/$1" "/opt/nfast/$1"
            }

            linkDir bin
            linkDir c
            linkDir document
            linkDir driver
            linkDir femcerts
            linkDir gcc
            linkDir java
            linkDir lib
            linkDir man
            linkDir nethsm-firmware
            linkDir openssl
            linkDir python
            linkDir sbin
            linkDir scripts
            linkDir share
            linkDir sslclient
            linkDir sslproxy
            linkDir tcl
            linkDir testdata
            linkDir toolkits
        '';
    };
}
