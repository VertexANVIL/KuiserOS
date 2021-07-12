## KuiserOS

This repository is intended to unify the common NixOS modules used for both Arctarus and my own machine configurations. The structure is inspired by [DevOS](https://github.com/divnix/devos), with a couple borrowed library functions.

Warning: Probably useful as a reference only! This contains some assumptions and defaults that you probably don't want, unless you are an Arctarus employee that is.

- `extern`: External imports. Same as with devos.
- `hosts`: Contains hosts, may or may not be present.
- `lib`: Shared library functions.
- `modules`: NixOS and home-manager modules.
- `overlays`: Package overlays.
- `overrides`: Overrides for modules, disabled modules, and unfree and unstable packages.
- `pkgs`: Structured the same as the `nixpkgs` folder tree, contains our own custom packages as well as supporting files and patches for existing ones.
- `profiles`: Shared NixOS machine configurations.
- `templates`: Top-level templates from which NixOS machine images (ISOs etc) can be built.
- `tools`: Supporting scripts and utilities that don't fit anywhere else.

### Building Images

[nixos-generators](https://github.com/nix-community/nixos-generators) is used to build KuiserOS ISOs. To generate an image, enter the shell with `nix develop`, and then use it like this:

```
nixos-generate -f iso --flake .#@default
```

### Operator Framework

The Operator Framework is part of the core of KuiserOS. It's a set of Python command-line utilities that provides an abstracted interface to deploy NixOS machines via Colmena and otherwise interact with the repository, available with the `operator` command.

The full list of commands is available via `operator --help`.

Examples:

- Listing all machines in the flake
```
[alex@kuiser:~/src/corp/arctarus/infra/nix]$ operator list
ID                 DNS                                      Reachability
-----------------  ---------------------------------------  --------------
ais.fra1.bdr1      ens18.bdr1.fra1.as210072.net             Down
ais.lon2.bdr1      ens18.bdr1.lon2.as210072.net             Up (16.189ms)
ais.stir1.descent  descent.stir1.arctarus.net               Up (28.727ms)
ais.stir1.dns1     dns1.stir1.arctarus.net                  Up (29.159ms)
ais.stir1.ubnt1    ubnt1.stir1.arctarus.net                 Up (29.143ms)
ais.stir1.vault1   vault1.stir1.arctarus.net                Up (29.482ms)
hcp.stir1.git      external-git.prod.self.stir1.hcpdns.net  Up (30.708ms)
misc.bode.avalon   srv1.avalonsrv.com                       Up (28.42ms)
```

- Deploying a machine
```
[alex@kuiser:~/src/corp/arctarus/infra/nix]$ operator deploy -m ais.lon2.bdr1
2021-07-11 01:39:58 kuiser kuiseros[220546] INFO Running deployment...
[INFO ] Enumerating nodes...
[INFO ] Selected 1 out of 8 hosts.
ais.lon2.bdr1 ✅ 0s Build successful
ais.lon2.bdr1 ✅ 1s Activation successful
2021-07-11 01:40:08 kuiser kuiseros[220546] INFO Running post-deploy actions...
2021-07-11 01:40:08 kuiser kuiseros[220546] DEBUG Updating Vault configuration for ais.lon2.bdr1
2021-07-11 01:40:10 kuiser kuiseros[220546] DEBUG 2 keys deployed
```

- Deploying multiple machines
```
[alex@kuiser:~/src/corp/arctarus/infra/nix]$ operator deploy -m ais.stir1.dns1,ais.stir1.vault1
2 machine(s) will be deployed:
    ais.stir1.dns1
    ais.stir1.vault1
Continue? Y/n: Y
2021-07-11 01:48:26 kuiser kuiseros[236327] INFO Running deployment...
[INFO ] Enumerating nodes...
[INFO ] Selected 2 out of 8 hosts.
           (...) ✅ 7s Build successful
ais.stir1.vault1 ✅ 1m Activation successful
  ais.stir1.dns1 ✅ 1m Activation successful
2021-07-11 01:50:42 kuiser kuiseros[236327] INFO Running post-deploy actions...
```
