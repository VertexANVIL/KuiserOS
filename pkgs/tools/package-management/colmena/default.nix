{ fetchFromGitHub, rustPlatform, ... }:

rustPlatform.buildRustPackage {
    name = "colmena";
    version = "0.1.0";

    src = fetchFromGitHub {
        owner = "zhaofengli";
        repo = "colmena";
        rev = "2886662e18e5500e032003745c4cf38ed4c2771d";
        sha256 = "sha256-w3i01it0ryRTpqLdD3i5bg2j3+wEmq699yROS9inGbw=";
    };

    cargoSha256 = "sha256-IRTfyauPTQx6VGt+8CIyAayD640ZLDQBiIOQH2eWGAo=";
}