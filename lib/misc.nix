{ ... }: let
    inherit (builtins) match pathExists;
in rec {
    # if path exists, evaluate expr with it, otherwise return other
    optionalPath = path: expr: other: if pathExists path then expr path else other;

    # if path exists, import it, otherwise return other
    optionalPathImport = path: other: optionalPath path (p: import p) other;

    # determines whether a given address is IPv6 or not
    isIPv6 = str: match ".*:.*" str != null;
}