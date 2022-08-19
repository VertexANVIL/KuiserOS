{ lib
, stdenv
, fetchurl
, makeWrapper
, autoPatchelfHook
, cups
, dpkg
, ghostscript
, file
, a2ps
, coreutils
, gnused
, gnugrep
, which
, gawk
}:

stdenv.mkDerivation rec {
  pname = "canon-cups-cque";
  version = "4.0";

  src = fetchurl {
    url = "https://files.canon-europe.com/files/soft45505/Driver/cque-en-${version}-10.x86_64.deb";
    hash = "sha256-ocQir8r/mYfHobSxnyg8J6jw/wwXrS1w6LLiG8mUABY=";
  };

  nativeBuildInputs = [ dpkg makeWrapper autoPatchelfHook ];
  buildInputs = [ cups ghostscript a2ps gawk ];
  unpackPhase = "dpkg-deb -x $src $out";

  installPhase = ''
    # Install the filter
    mkdir -p $out/lib/cups/filter
    ln -s $out/opt/cel/bin/sicgsfilter $out/lib/cups/filter/sicgsfilter

    # Install the models
    mkdir -p $out/share/cups/model
    install -m 644 $out/opt/cel/ppd/*.ppd.gz $out/share/cups/model/

    # Wrap the filter binary
    wrapProgram $out/opt/cel/bin/sicgsfilter \
      --prefix PATH ":" ${lib.makeBinPath [
        gawk
        ghostscript
        a2ps
        file
        gnused
        gnugrep
        coreutils
        which
      ]}
  '';

  meta = with lib; {
    homepage = "https://www.canon.com";
    description = "Canon CQue print drivers";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = with maintainers; [ citadelcore ];
  };
}
