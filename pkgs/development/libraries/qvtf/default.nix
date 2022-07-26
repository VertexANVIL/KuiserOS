{ stdenv
, lib
, cmake
, pkgconfig
, extra-cmake-modules
, qt5
, shared-mime-info
, vtflib
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "qvtf";
  version = "master";

  src = fetchFromGitHub {
    rev = version;
    owner = "panzi";
    repo = "qvtf";
    sha256 = "sha256-jjWhUFVfSC7M2NL5H7EaQCUKXuApV9NNprWmnREjjWM=";
  };

  buildInputs = [
    qt5.qtbase
    shared-mime-info
    vtflib
  ];

  nativeBuildInputs = [
    cmake
    pkgconfig
    extra-cmake-modules
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  dontWrapQtApps = true;

  enableParallelBuilding = true;

  meta = {
    homepage = "https://github.com/panzi/qvtf";
    description = "QImageIO plugin to load Valve Texture Files";
    license = lib.licenses.gpl2;
  };
}
