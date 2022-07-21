#!/usr/bin/env bash
nix build nixpkgs#fwupd-efi --no-link
RPATH=$(nix eval nixpkgs#fwupd-efi.outPath --raw)
KEYDIR=/persist/secrets/secureboot
sbsign $RPATH/libexec/fwupd/efi/fwupdx64.efi --key $KEYDIR/db.key --cert $KEYDIR/db.crt --output fwupdx64.efi.signed
