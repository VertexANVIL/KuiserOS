{ pkgs, ... }:
{
    # enable development documentation
    documentation.dev.enable = true;

    # enable kernel debugging disabled in security hardening profile
    boot.kernel.sysctl."kernel.ftrace_enabled" = true;

    # nix related tools
    environment.systemPackages = with pkgs; [
        manix
    ];
}
