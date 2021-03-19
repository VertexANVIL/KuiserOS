final: prev: {
    deploy-rs = prev.deploy-rs.overrideAttrs (self: {
        patches = (self.patches or []) ++ [
            # HACK: Replaces `sudo` with `doas` in deploy commands
            ../pkgs/tools/package-management/deploy-rs/0001-replace-sudo-with-doas.patch
        ];
    });
}