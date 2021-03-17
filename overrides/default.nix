{
    modules = [];
    disabledModules = [];

    packages = [(pkgs: final: prev: with pkgs; {
        # needed for our patch
        inherit nixFlakes;

        inherit dotnet-sdk_5 omnisharp-roslyn;
        inherit vscode-extensions;
    })];
}