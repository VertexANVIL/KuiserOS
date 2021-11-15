{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "talosctl";
    version = "0.13.2";

    src = fetchurl {
        url = "https://github.com/talos-systems/talos/releases/download/v${version}/talosctl-linux-amd64";
        sha256 = "sha256-5dWVpcqTgTLJM564Zy3HKJW6coHVdxHcSHzm0+1CuGo=";
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
        mkdir -p $out/bin
        cp ${src} $out/bin/talosctl
        chmod a+x $out/bin/talosctl
    '';

    meta = with lib; {
        description = "Talos is a modern OS for Kubernetes.";
        homepage = "https://www.talos.dev";
        license = licenses.mpl20;
        maintainers = with maintainers; [ citadelcore ];
        platforms = platforms.unix;
    };
}
