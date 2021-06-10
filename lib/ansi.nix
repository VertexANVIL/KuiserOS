{ lib, pkgs ? null, ... }:

# Provides standard ANSI Control Codes for prettifying text

let
    inherit (builtins) readFile;
    inherit (lib) mapAttrsRecursive;

    codes = {
        reset = 0;
        bold = 1;
        dim = 2;
        italic = 3;
        underline = 4;
        blink = 5;
        reverse = 7;
        hidden = 8;
        strike = 9;

        fg = {
            black = 30;
            red = 31;
            green = 32;
            yellow = 33;
            blue = 34;
            magneta = 35;
            cyan = 36;
            lightGrey = 37;
            darkGrey = 38;
            default = 39;

            lightRed = 91;
            lightGreen = 92;
            lightYellow = 93;
            lightBlue = 94;
            lightMagneta = 95;
            lightCyan = 96;
            white = 97;
        };

        bg = {
            black = 40;
            red = 41;
            green = 42;
            yellow = 43;
            blue = 44;
            magneta = 45;
            cyan = 46;
            lightGrey = 47;
            default = 49;

            darkGrey = 100;
            lightRed = 101;
            lightGreen = 102;
            lightYellow = 103;
            lightBlue = 104;
            lightMagneta = 105;
            lightCyan = 106;
            white = 107;
        };
    };
in (mapAttrsRecursive (_: v: "\\033[${toString v}m") codes) // {
    # Compiles colour codes to their actual characters
    compile = text: let
        file = pkgs.writeText "ansi-compile" text;
        result = pkgs.runCommand "ansi-compile" {} ''echo -e "$(cat ${file})" > $out'';
    in readFile result;
}
