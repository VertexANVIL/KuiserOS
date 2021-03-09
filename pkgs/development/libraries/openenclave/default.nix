{ type }:
assert builtins.elem type [ "sgx" ];

{ lib
, gdb
, gcc10
, cmake
, libcxx
, llvmPackages_8
, fetchurl
, fetchFromGitHub
, openssl
, perl
, valgrind
, doxygen
, python3
}:

let
    intelTools = rec {
        version = "2.13";
        url = "https://download.01.org/intel-sgx/sgx-linux/${version}";
        src = fetchurl {
            url = "${url}/as.ld.objdump.gold.r3.tar.gz";
            sha256 = "sha256-eUljypD7BWHK8+0r7h2bo5QibzVWic3aKBYebgYgpxM=";
        };
    };

    clang = llvmPackages_8.clang;
in llvmPackages_8.stdenv.mkDerivation rec {
    pname = "openenclave-${type}";
    version = "0.14.0";

    src = fetchFromGitHub {
        owner = "openenclave";
        repo = "openenclave";
        rev = "v${version}";
        sha256 = "sha256-ffXDVEmTeqNvYJ497LGV8NONu/CibfCZ8+nNsjrONOs=";
        fetchSubmodules = true;
    };

    patchPhase = ''
        patchShebangs 3rdparty/musl/append-deprecations
        patchShebangs 3rdparty/openssl/append-unsupported
        patchShebangs tests/crypto/data/make-test-certs
        patchShebangs tests/crypto_crls_cert_chains/data/make-test-certs
        patchShebangs scripts/lvi-mitigation/generate_wrapper
        patchShebangs scripts/lvi-mitigation/invoke_compiler

        substituteInPlace debugger/oegdb \
            --replace 'gdb -iex' '${gdb}/bin/gdb -iex'
        substituteInPlace scripts/lvi-mitigation/invoke_compiler \
            --replace '/usr/bin/"$compiler"' '"$compiler"' \
            --replace 'export PATH=/bin:/usr/local:"$lvi_bin_path"' 'export PATH=$PATH:"$lvi_bin_path"'
    '';

    preConfigure = let
        mkWrapper = name: ''
            scripts/lvi-mitigation/generate_wrapper --name=${name} --path=lvi_mitigation_bin
            patchShebangs lvi_mitigation_bin/${name}
        '';
    in ''
        mkdir -p lvi_mitigation_bin
        tar -zxf ${intelTools.src} -C lvi_mitigation_bin/
        cp scripts/lvi-mitigation/invoke_compiler lvi_mitigation_bin/

        ln -s ${gcc10}/bin/gcc lvi_mitigation_bin/gcc_symlink
        ln -s ${gcc10}/bin/g++ lvi_mitigation_bin/g++_symlink

        ln -s ${clang}/bin/clang lvi_mitigation_bin/clang_symlink
        ln -s ${clang}/bin/clang++ lvi_mitigation_bin/clang++_symlink

        ${mkWrapper "gcc"}
        ${mkWrapper "g++"}

        ${mkWrapper "clang"}
        ${mkWrapper "clang++"}
    '';

    buildInputs = [ openssl ];

    nativeBuildInputs = [
        gcc10 llvmPackages_8.clang
        cmake perl valgrind doxygen python3
    ];

    cmakeFlags = [
        "-DCMAKE_BUILD_TYPE=Release"
        #"-DENABLE_FULL_LIBCXX_TESTS=ON"
        #"-DENABLE_FULL_STRESS_TESTS=ON"
        "-DENABLE_REFMAN=ON"

        "-DLVI_MITIGATION=ControlFlow"
        "-DLVI_MITIGATION_BINDIR=/build/source/lvi_mitigation_bin"
    ];

    # required, otherwise we fail on -nostdinc++
    NIX_CFLAGS_COMPILE = "-Wno-unused-command-line-argument";
}
