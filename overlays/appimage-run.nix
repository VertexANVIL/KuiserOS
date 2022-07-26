final: prev: {
  appimage-run = prev.appimage-run.override {
    extraPkgs = pkgs: with pkgs; [ xorg.libxshmfence ];
  };
}
