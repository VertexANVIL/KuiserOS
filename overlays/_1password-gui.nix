final: prev: {
    _1password-gui = prev._1password-gui.overrideAttrs (o: {
        nativeBuildInputs = with final; [ makeWrapper glib wrapGAppsHook ];
    });
}
