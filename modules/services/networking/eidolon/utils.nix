{ config, lib, ... }:

with lib;

let
    eidolon = config.services.eidolon;

    underlay = eidolon.underlay;
    underlayAddr = v: elemAt config.networking.interfaces.${eidolon.underlay}."ipv${toString v}".addresses 0;

    parsePrefixRoute = str: let
        spl = splitString "/" str;
    in
        assert (assertMsg ((length spl) == 2) "Malformed IP ${str}");
    {
        address = elemAt spl 0;
        prefixLength = toInt (elemAt spl 1);
    };
in {
    inherit underlay underlayAddr parsePrefixRoute;
}
