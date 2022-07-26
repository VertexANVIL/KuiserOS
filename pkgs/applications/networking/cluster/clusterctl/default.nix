{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "clusterctl";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "cluster-api";
    rev = "v${version}";
    sha256 = "sha256-/VwTPSPy1WFgYp8QehSc8Hhum/BrzsmxIhIRt8QCUrg=";
  };

  vendorSha256 = "sha256-+/Rmdn/+OSMbJvg6j3JdxRknYUWPJ7T+UDkSOM3Shq8=";

  subPackages = [ "cmd/clusterctl" ];

  meta = with lib; {
    description = "Home for the Cluster Management API work, a subproject of sig-cluster-lifecycle";
    homepage = "https://cluster-api.sigs.k8s.io";
    maintainers = with maintainers; [ citadelcore ];
    platforms = platforms.unix;
  };
}
