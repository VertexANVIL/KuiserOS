{ nixos, lib, ... }:
let
    inherit (builtins) readFile readDir;
    inherit (nixos.lib) hasSuffix removeSuffix nameValuePair;
    inherit (lib) mapFilterAttrs;

    certPath = ./../profiles/core/security/certs;
in {
    certs = mapFilterAttrs (_: v: v != null) (n: v:
        if v != "directory" && hasSuffix ".pem" n then
            let name = removeSuffix ".pem" n; in nameValuePair name (readFile (certPath + "/${n}"))
        else nameValuePair "" null
    ) (readDir certPath);
}
