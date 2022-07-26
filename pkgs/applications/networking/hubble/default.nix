{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "hubble";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "cilium";
    repo = "hubble";
    rev = "v${version}";
    sha256 = "sha256-5BBA1GmeCR1oT+JYi20yGvYLCOmK+w7IoLAfVYsmi+4=";
  };

  vendorSha256 = null;

  meta = with lib; {
    description = "Network, Service & Security Observability for Kubernetes using eBPF";
    homepage = "https://cilium.io";
    license = licenses.asl20;
    maintainers = with maintainers; [ citadelcore ];
    platforms = platforms.unix;
  };
}
