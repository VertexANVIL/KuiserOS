{
    stdenv, lib, fetchFromGitHub, pkgconfig, autoconf, automake, texi2html, gettext, zip, doxygen, graphviz, imagemagick,
    SDL2, SDL2_ttf, SDL2_mixer, SDL2_image, xercesc, libpng, zlib, curl, xdg_utils
}:

stdenv.mkDerivation rec {
    pname = "enigma";
    version = "1.30-alpha";

    src = fetchFromGitHub {
        rev = version;
        owner = "Enigma-Game";
        repo = "Enigma";
        sha256 = "sha256-oCNQFmMPeRGWCJWOe1hbbOtQvLVbIvMRZvBkJfG7nUU=";
    };

    buildInputs = [ SDL2 SDL2_ttf SDL2_mixer SDL2_image xercesc libpng zlib curl xdg_utils ];
    nativeBuildInputs = [ pkgconfig autoconf automake texi2html gettext zip doxygen graphviz imagemagick ];

    preConfigure = "./autogen.sh";
    enableParallelBuilding = true;

    # Add the SDL2 include dirs explicitly because for some reason they aren't found
    NIX_CFLAGS_COMPILE = "-I${SDL2.dev}/include/SDL2 -I${SDL2_ttf}/include/SDL2 -I${SDL2_mixer}/include/SDL2 -I${SDL2_image}/include/SDL2";
    
    meta = with lib; {
        description = "Enigma is a puzzle game inspired by Oxyd on the Atari ST and Rock'n'Roll on the Amiga.";
        homepage = "http://www.nongnu.org/enigma/index.html";
        license = licenses.gpl3;
        platforms = platforms.all;
    };
}