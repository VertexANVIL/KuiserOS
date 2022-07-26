{ pkgs, ... }:
{
    # enable development documentation
    documentation.dev.enable = true;

    # nix related tools
    environment.systemPackages = with pkgs; [
        manix
    ];
}
