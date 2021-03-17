{ lib, pkgs, ... }:
{
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
}