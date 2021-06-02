final: prev: {
    gnome = prev.gnome.overrideScope' (finalx: prevx: {
        gnome-settings-daemon = prevx.gnome-settings-daemon.overrideAttrs (o: {
            patches = [ ../pkgs/desktops/gnome-3/core/gnome-settings-daemon/0001-increase-ambient-hz.patch ];
        });
    });
}