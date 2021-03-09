final: prev: {
    autorandr = prev.autorandr.overrideAttrs (o: {
        patches = [ ../pkgs/tools/misc/autorandr/0001-fix-disable.patch ];
    });
}