final: prev: {
  discord = prev.discord.override {
    # https://github.com/NixOS/nixpkgs/issues/78961
    nss = final.nss_latest;
  };
}
