final: prev: with prev; let
  efiBlob = ../pkgs/os-specific/linux/firmware/fwupd-efi/fwupdx64.efi.signed;
in
{
  fwupd-efi = prev.fwupd-efi.overrideAttrs (o: {
    # to prevent use of nix as a signing oracle,
    # we pre-sign the fwupd binaries and include the signed efi object blob
    # this is done with the "resign-fwupd-efi.sh" script
    postBuild = lib.optionalString (builtins.pathExists efiBlob) ''
      mkdir -p $out/libexec/fwupd/efi
      cp ${efiBlob} $out/libexec/fwupd/efi/fwupdx64.efi.signed
    '';
  });
}
