#!/usr/bin/env bash
RPATH=$(nix-build '<nixpkgs>' -A fwupd --no-out-link)
KEYDIR=./../../../../../secrets/secureboot
sbsign $RPATH/libexec/fwupd/efi/fwupdx64.efi --key $KEYDIR/db.key --cert $KEYDIR/db.crt --output fwupdx64.efi.signed
