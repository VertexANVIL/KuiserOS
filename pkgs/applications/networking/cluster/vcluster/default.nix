{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
    pname = "vcluster";
    version = "0.3.3";

    src = fetchFromGitHub {
        owner = "loft-sh";
        repo = "vcluster";
        rev = "v${version}";
        sha256 = "sha256-jG2xhX9B+30OIPegjjOAbnYUi+qrsUAHiWtlQZq5oB4=";
    };

    vendorSha256 = null;

    subPackages = [ "cmd/vclusterctl" ];

    postInstall = ''
        mv $out/bin/vclusterctl $out/bin/vcluster
    '';

    meta = with lib; {
        description = "Create fully functional virtual Kubernetes clusters";
        homepage = "https://www.vcluster.com";
        license = licenses.asl20;
        maintainers = with maintainers; [ citadelcore ];
        platforms = platforms.unix;
    };
}
