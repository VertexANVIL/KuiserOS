{
    modules = [
        # need the `settings` attribute to override configuration
        "virtualisation/containerd.nix"
    ];
    disabledModules = [];

    # allowed unfree packages
    unfree = [
        "p4" "p4v" "steam" "steam-original" "steam-runtime"
        "nvidia-x11" "nvidia-settings" "nvidia-persistenced"
    ];

    packages = [(pkgs: final: prev: with pkgs; {
        # needed for our patch
        #inherit nixFlakes nixUnstable; # WHAT ???

        inherit dotnet-sdk_5 omnisharp-roslyn;
        inherit vscode-extensions;
    })];
}