{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "cilium-cli";
  version = "0.8.5";

  src = fetchFromGitHub {
    owner = "cilium";
    repo = "cilium-cli";
    rev = "v${version}";
    sha256 = "sha256-TpcEvzQ5t9gdpxx59yPdzliotBoLooDMjA1bWpkFv0M=";
  };

  vendorSha256 = null;

  meta = with lib; {
    description = "CLI to install, manage & troubleshoot Kubernetes clusters running Cilium ";
    homepage = "https://cilium.io";
    license = licenses.asl20;
    maintainers = with maintainers; [ citadelcore ];
    platforms = platforms.unix;
  };
}
