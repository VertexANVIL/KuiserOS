{ pkgs, ... }:
{
    imports = [
        ./certs
        ./hardening
        ./pam
        ./secureboot
        ./smartcard
    ];

    programs.ssh.startAgent = true;

    security = {
        # enable auditing
        auditd.enable = true;

        # enable intel SGX support
        sgx.enable = true;

        # replace sudo with doas
        sudo.enable = false;

        doas = {
            enable = true;
            extraRules = [
                {
                    groups = [ "wheel" ];
                    noPass = false;
                    persist = true;
                    setEnv = [ "COLORTERM" "NIX_PATH" "PATH" ];
                }
            ];
        };
    };
}
