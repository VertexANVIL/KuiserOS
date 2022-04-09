final: prev: with prev; {
    p4 = prev.p4.overrideAttrs (o: {
        src = fetchurl {
            url = "https://cdist2.perforce.com/perforce/r21.2/bin.linux26x86_64/helix-core-server.tgz";
            sha256 = "sha256-BKts8Pr2r6J5N4SBLtd+pbWDLtiHl3YAjaeKqtVmYqE=";
        };
    });
}
