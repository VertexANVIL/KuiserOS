final: prev: {
    gnome = prev.gnome.overrideScope' (finalx: prevx: {
        gnome-session = prevx.gnome-session.overrideAttrs (o: {
            patches = [ ../pkgs/desktops/gnome-3/core/gnome-session/0001-fix-dbus-service.patch ];
        });

        gnome-settings-daemon = prevx.gnome-settings-daemon.overrideAttrs (o: {
            patches = [ ../pkgs/desktops/gnome-3/core/gnome-settings-daemon/0001-increase-ambient-hz.patch ];
        });
    });

    gnomeExtensions = {
        topicons-plus = prev.gnomeExtensions.topicons-plus.overrideAttrs (o: rec {
            # bump the version so we're compatible with unstable gnome (nixos 21.05)
            version = "37";

            src = prev.fetchFromGitHub {
                owner = "ubuntu";
                repo = "gnome-shell-extension-appindicator";
                rev = "v${version}";
                sha256 = "1d8kyhzxi932vmsrr204770h0ww2bq85yjjlwf080r51v8s5jrm6";
            };
        });
    };
}