{ lib, pkgs, ... }:

let
    # Little helper to run nixos-rebuild while overriding the arnix path
    nrbScript = pkgs.writeShellScriptBin "nrb" ''
        EXTRA_ARGS=""

        # if ARNIX_REPO_PATH is set and exists use that
        if [[ -v ARNIX_REPO_PATH ]] && [[ -d "$ARNIX_REPO_PATH" ]]; then
            echo "Using local Arnix repository at $ARNIX_REPO_PATH."
            EXTRA_ARGS="$EXTRA_ARGS --no-write-lock-file --override-input arnix $ARNIX_REPO_PATH"
        fi

        sudo nixos-rebuild $EXTRA_ARGS "$@"
    '';
in {
    nix = {
        package = pkgs.nixFlakes;
        systemFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];

        autoOptimiseStore = true;
        optimise.automatic = true;

        gc = {
            automatic = true;

            options = let
                keep-gb = 5; # keep 5gb of space free
                cur-avail-cmd = "df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }'";
                # free `${keep-gb} - ${cur-avail}` of space
                max-freed-expression = "${toString keep-gb} * 1024**3 - 1024 * $(${cur-avail-cmd})";
            in lib.mkDefault ''--delete-older-than 14d --max-freed "$((${max-freed-expression}))"'';
        };

        extraOptions = ''
            experimental-features = nix-command flakes ca-references
            min-free = 536870912
        '';
    };

    environment.systemPackages = [ nrbScript ];
}