{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
    pname = "talosctl";
    version = "1.0.0";

    src = fetchurl {
        url = "https://github.com/talos-systems/talos/releases/download/v${version}/talosctl-linux-amd64";
        sha256 = "sha256-RiaXrYCcu4B8+2tLT8DwbxJ0DHEw+UsaQANfW8EtTbA=";
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
