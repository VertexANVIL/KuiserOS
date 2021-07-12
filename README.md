## KuiserOS

This repository is an *experimental* NixOS framework that implements many of the features found in [DevOS](https://github.com/divnix/devos), however targeted towards complex enterprise deployments.

Examples of KuiserOS configuration repositories:
  - https://github.com/CitadelCore/nixflk

### Features

While KuiserOS is similar to DevOS in many ways, logically it is a rewrite from the ground up and does not share much code from the latter.

- **Operator**. The Operator component of KuiserOS is a set of Python tooling available as `operator` from any KuiserOS repo with the `nix develop` command. This allows you to list, inspect, and deploy machines, via the deployment tool Colmena.
- **Composability**. This is an integral part of KuiserOS, and allows configuration from multiple repositories to be merged together in order to facilitate DRY principles. `lib`, `users`, `profiles`, `extern`, and `overrides` are combined.
- **Complex monorepo support**. Through the `generator` argument on `mkRepo`, you can divide your systems up into collections, like regions, allowing everything to remain located in one place while staying tidy.
- **Eidolon RIS**. Eidolon RIS, a declarative meshed BGP routing solution, is available through KuiserOS with the `services.eidolon.enable` attribute. See the [readme](./modules/services/networking/eidolon/README.md) for more information.
- KuiserOS by default builds clean with sensible security hardening options enabled by default, unless you choose to explicitly disable them.
- Many useful library functions not available in NixOS are included, as well as convenience attributes like systemd hardening profiles, are included.
- The convenience tool `inix` is included to make working with flakes less painful. Simply set the `$NIX_FLAKE_URL_OVERRIDES` environment variable, and the `inix` command will override flake inputs automatically without you having to type `--override-input` every time.

Differences between KuiserOS and DevOS:
- By default, the `hosts` folder behaves the same as DevOS (one .nix file per host), but this is configurable to be a folder per host instead.
- For simplicitly, suites are not supported. The reasoning here is that you can do everything that suites can do just by creating your own profiles.
- KuiserOS implements its own profile import system, via `mkProfile` and the `requires` attribute.
- KuiserOS is currently not compatible with legacy tools such as `nixos-option`. This will be supported in the future.

### Folder Structure

- `extern`: (Same as DevOS) External imports.
- `hosts`: (Same as DevOS) Contains hosts, may or may not be present.
- `lib`: Shared library functions.
- `modules`: NixOS and home-manager modules.
- `overlays`: Package overlays.
- `overrides`: Overrides for modules, disabled modules, and unfree and unstable packages.
- `pkgs`: Structured the same as the `nixpkgs` folder tree, contains our own custom packages as well as supporting files and patches for existing ones.
- `profiles`: Shared NixOS machine configurations.
- `templates`: Top-level templates from which NixOS machine images (ISOs etc) can be built.

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
