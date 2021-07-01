{
    stdenv, fetchFromGitHub,
    jansson, rsync, curl, libxml2,
    pkgconfig, autoconf, automake, autoreconfHook
}:

stdenv.mkDerivation rec {
    pname = "fort-validator";
    version = "1.5.0";

    src = fetchFromGitHub {
        rev = "v${version}";
        owner = "NICMx";
        repo = "FORT-validator";
        sha256 = "sha256-sldN/xg+agdunTln2q03XEjSwyDtDJucv+9YizP4nw8=";
    };

    buildInputs = [
        jansson rsync curl libxml2
    ];

    nativeBuildInputs = [
        pkgconfig autoconf automake autoreconfHook
    ];
}