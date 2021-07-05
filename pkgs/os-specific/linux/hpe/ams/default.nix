{ lib, stdenv, autoPatchelfHook, dpkg, fetchurl }:

stdenv.mkDerivation rec {
    pname = "hp-ams";
    version = "2.8.3";

    src = fetchurl {
        url = "http://downloads.linux.hpe.com/SDR/repo/mcp/debian/pool/non-free/hp-ams_2.8.3-3056.1ubuntu16_amd64.deb";
        sha256 = "sha256-OR7T7XRFnsBH6ccwqWQQUHm3iF1mbQnJH4dfez6b0TI=";
    };

    nativeBuildInputs = [ autoPatchelfHook dpkg ];

    installPhase = ''
        mkdir -p "$out/sbin"
        cp -R "opt" "$out"
        cp -R "usr/share" "$out/share"
        chmod -R g-w "$out"
    '';

    meta = with lib; {
        description = "HP Agentless Management Service";
        homepage = "https://buy.hpe.com/uk/en/software/server-management-software/server-ilo-management/ilo-management-engine/hpe-agentless-management/p/5219980";
        license = licenses.unfree;
        maintainers = with maintainers; [ citadelcore ];
    };
}
