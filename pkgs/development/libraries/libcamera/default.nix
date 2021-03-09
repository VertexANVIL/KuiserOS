{ stdenv
, fetchgit
, lib
, meson
, ninja
, pkg-config
, boost
, gnutls
, openssl
, libevent
, lttng-ust
, libtiff
, qt5
, gst_all_1
, graphviz
, doxygen
, python3
, python38Packages
}:

stdenv.mkDerivation {
    pname = "libcamera";
    version = "1.0.0";

    src = fetchgit {
        url = "git://linuxtv.org/libcamera.git";
        rev = "040a6dcfbccaf1005da2c571769b1f89df1f07cf";
        sha256 = "sha256-RCNKFCv3fNabroCUR5MtKbyDS20J7leU8KkE1U5qe1M=";
    };

    patchPhase = ''
        patchShebangs utils/
    '';

    buildInputs = [
        # core requirements
        python38Packages.pyyaml
        python38Packages.ply
        python38Packages.jinja2

        # IPA and signing
        gnutls openssl boost

        # gstreamer integration
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base

        # cam integration
        libevent

        # qcam integration
        qt5.qtbase qt5.qttools libtiff

        # lttng tracing
        lttng-ust
    ];

    nativeBuildInputs = [
        meson ninja pkg-config python3
        python38Packages.sphinx graphviz doxygen
    ];

    mesonFlags = [
        "-Dv4l2=true"
    ];

    dontWrapQtApps = true;

    meta = with lib; {
        description = "An open source camera stack and framework for Linux, Android, and ChromeOS";
        homepage = "https://libcamera.org";
        license = licenses.bsd2;
    };
}