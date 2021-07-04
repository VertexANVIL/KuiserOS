{ lib, ... }: let
    inherit (lib) mkOption types;
in rec {
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

    # Converts an address object to a string
    addrToString = addr: "${addr.address}/${toString addr.prefixLength}";
    
    # Convers a string to an address object
    addrToOpts = addr: v: { address = addr; prefixLength = if v == 4 then 32 else 128; };
    addrsToOpts = addrs: v: map (addr: addrToOpts addr v) addrs;
}