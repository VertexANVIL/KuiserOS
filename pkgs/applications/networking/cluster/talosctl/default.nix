{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
    pname = "talosctl";
    version = "0.11.3";

    src = fetchFromGitHub {
        owner = "talos-systems";
        repo = "talos";
        rev = "v${version}";
        sha256 = "sha256-oqcCAlaUnD5KOGnWBClUh/Z7NHt3YjXsNTkZsq+jWDY=";
    };

    vendorSha256 = "sha256-s+takXwg2ww3CGL1DboguMiBmzBuULhFv8OGpliFFyM=";

    subPackages = [ "cmd/talosctl" ];

    meta = with lib; {
        description = "Talos is a modern OS for Kubernetes.";
        homepage = "https://www.talos.dev";
        license = licenses.mpl20;
        maintainers = with maintainers; [ citadelcore ];
        platforms = platforms.unix;
    };
}
