let
    basePath = "/persist/nixos/secrets/secureboot";
in
{
    boot.loader.systemd-boot = {
        signed = true;
        signing-key = "${basePath}/db.key";
        signing-certificate = "${basePath}/db.crt";
    };
}
