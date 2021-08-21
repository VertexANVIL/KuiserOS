final: prev: with prev; {
    p4 = prev.p4.overrideAttrs (o: {
        src = fetchurl {
            url = "https://cdist2.perforce.com/perforce/r20.1/bin.linux26x86_64/helix-core-server.tgz";
            sha256 = "sha256-NmXWllJk4rK1Z8rxngSOGONo2zoRMLAsUnPialbRP/I=";
        };
    });
}
