final: prev: {
    colmena = let
        colmenaWrapped = prev.writeShellScriptBin "colmena" ''
            IFS=';' read -ra ARGS <<< $(${final.inix-helper}/bin/inix-helper)
            COLMENA_NIX_ARGS="''\${ARGS[@]} --quiet --quiet" ${prev.colmena}/bin/colmena "$@"
        '';
    in prev.symlinkJoin {
        name = "colmena";
        paths = [ colmenaWrapped prev.colmena ];
    };
}