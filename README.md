## ARNIX

This repository is intended to unify the common NixOS modules used for both Arctarus and my own machine configurations. The structure is inspired by [DevOS](https://github.com/divnix/devos), with a couple borrowed library functions.

Warning: Probably useful as a reference only! This contains some assumptions and defaults that you probably don't want, unless you are an Arctarus employee that is.

- `extern`: External imports. Same as with devos.
- `lib`: Shared library functions.
- `modules`: NixOS and home-manager modules.
- `overlays`: Package overlays.
- `overrides`: Overrides for modules, disabled modules, and unfree and unstable packages.
- `pkgs`: Structured the same as the `nixpkgs` folder tree, contains our own custom packages as well as supporting files and patches for existing ones.
- `profiles`: Shared NixOS machine configurations.
- `templates`: Top-level templates from which NixOS machine images (ISOs etc) can be built.
- `tools`: Supporting scripts and utilities that don't fit anywhere else.
