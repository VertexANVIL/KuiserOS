{ config, lib, utils, regions ? {}, ... }:

with lib;

let
    eidolon = config.services.eidolon;

    addrOpts = v:
    assert v == 4 || v == 6;
    { 
        options = {
            address = mkOption {
                type = types.str;
                description = "IPv${toString v} address.";
            };

            prefixLength = mkOption {
                type = types.addCheck types.int (n: n >= 0 && n <= (if v == 4 then 32 else 128));
                description = ''
                    Subnet mask of the interface, specified as the number of
                    bits in the prefix (<literal>${if v == 4 then "24" else "64"}</literal>).
                '';
            };
        };
    };

    underlay = config.services.eidolon.underlay;
    underlayAddr = region: node: v: let cfg = regions.${region}.${node}.config; in
    (elemAt cfg.networking.interfaces.${cfg.services.eidolon.underlay}."ipv${toString v}".addresses 0);

    # Converts an address object to a string
    addrToString = addr: "${addr.address}/${toString addr.prefixLength}";
    
    # Convers a string to an address object
    addrToOpts = addr: v: { address = addr; prefixLength = if v == 4 then 32 else 128; };
    addrsToOpts = addrs: v: map (addr: addrToOpts addr v) addrs;
in {
    inherit addrOpts underlay underlayAddr addrToString addrsToOpts;
}
