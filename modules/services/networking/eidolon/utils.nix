{ config, lib, utils, regions ? {}, ... }:

with lib;

let
    eidolon = config.services.eidolon;

    underlay = eidolon.underlay;
    underlayAddr = region: node: v: let cfg = regions.${region}.${node}.config; in
    (elemAt cfg.networking.interfaces.${eidolon.underlay}."ipv${toString v}".addresses 0);
in {
    inherit underlay underlayAddr;
}
