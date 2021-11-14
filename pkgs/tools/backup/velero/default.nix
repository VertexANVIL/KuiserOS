{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
    pname = "velero";
    version = "1.7.0";

    src = fetchFromGitHub {
        owner = "vmware-tanzu";
        repo = "velero";
        rev = "v${version}";
        sha256 = "0723milq4zr7wf7r9jdb45kr1b6lhkjqnnf4wq421swvbkw6954z";
    };

    vendorSha256 = "sha256-qsRbwLKNnuQRIsx0+sfOfR2OQ0+el0vptxz7mMew7zY=";

    subPackages = [ "cmd/velero" ];

    meta = with lib; {
        description = "Backup and migrate Kubernetes applications and their persistent volumes";
        homepage = "https://velero.io";
        license = licenses.asl20;
        maintainers = with maintainers; [ citadelcore ];
        platforms = platforms.unix;
    };
}
