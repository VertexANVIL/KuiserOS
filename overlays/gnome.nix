final: prev: {
    gnome3 = prev.gnome3.overrideScope' (finalx: prevx: {
        gnome-session = prevx.gnome-session.overrideAttrs (o: {
            patches = [ ../pkgs/desktops/gnome-3/core/gnome-session/0001-fix-dbus-service.patch ];
        });

        gnome-settings-daemon = prevx.gnome-settings-daemon.overrideAttrs (o: {
            patches = [ ../pkgs/desktops/gnome-3/core/gnome-settings-daemon/0001-increase-ambient-hz.patch ];
        });
    });

    gnomeExtensions = {
        topicons-plus = prev.gnomeExtensions.topicons-plus.overrideAttrs (o: rec {
            # bump the version so we're compatible with unstable gnome3 (nixos 21.05)
            version = "27";

            src = prev.fetchFromGitHub {
                owner = "phocean";
                repo = "TopIcons-plus";
                rev = version;
                sha256 = "sha256-efpQPtseYyFaPujNRK6E2tpM9o6+nqqQ39m+T/Smctw=";
            };

            meta.broken = false;
        });
    };
}