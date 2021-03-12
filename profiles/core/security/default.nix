{ pkgs, ... }:
{
    imports = [
        ./certs
        ./hardening
        ./pam
        ./smartcard
    ];

    security = {
        # enable auditing
        auditd.enable = true;

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
