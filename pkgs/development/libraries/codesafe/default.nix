{
    lib,
    stdenv,
    fetchzip,
    autoPatchelfHook,

    # other stuff
    gtk2,
    libSM,
    libpng12,
    ncurses5,
    pcsclite,
    freetype,
    libXxf86vm,
    libXScrnSaver
}:

stdenv.mkDerivation rec {
    pname = "codesafe";
    version = "12.10.01";

    src = fetchzip {
        url = "https://backblast.s3.eu-central-003.backblazeb2.com/ncipher/codesafe-linux64-dev-${version}.zip";
        sha256 = "sha256-KYawGGSdElhmqPNUf5Iz+xHMUsQnltPjyoJ1wtyh+P0=";
    };

    nativeBuildInputs = [
        autoPatchelfHook
    ];

    buildInputs = [
        gtk2
        libSM
        libpng12
        ncurses5
        pcsclite
        freetype
        libXxf86vm
        libXScrnSaver
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
        mkdir $out
        cd $out

        tar xf $src/linux/libc6_11/amd64/nfast/csd/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/devref/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/jcecsp/user.tar
        tar xf $src/linux/libc6_11/amd64/nfast/javasp/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/hwsp/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/ctls/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/hwcrhk/gnupg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/hwcrhk/user.tar
        tar xf $src/linux/libc6_11/amd64/nfast/jd/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/nhfw/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/ratls/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/gccsrc/ppcdev.tar
        tar xf $src/linux/libc6_11/amd64/nfast/csd/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/dsserv/user.tar
        #tar xf $src/linux/libc6_11/amd64/nfast/snmp/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/csdref/agg.tar
        tar xf $src/linux/libc6_11/amd64/nfast/pkcs11/user.tar
    '';

    meta = with lib; {
        description = "Develop and execute sensitive code within a FIPS 140-2 Level 3 certified nShield hardware security module.";
        homepage = "https://www.entrust.com/digital-security/hsm/products/nshield-software/codesafe";
        maintainers = with maintainers; [ citadelcore ];
        platforms = platforms.unix;
    };
}
