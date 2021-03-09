{
    modules = [];
    disabledModules = [];

    packages = pkgs: final: prev: with pkgs; {
        inherit dotnet-sdk_5 omnisharp-roslyn;
        inherit vscode-extensions;
    };
}