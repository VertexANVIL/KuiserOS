final: prev: with prev; let
    efiBlob = ../pkgs/os-specific/linux/firmware/fwupd/fwupdx64.efi.signed;
in {
    fwupd = prev.fwupd.overrideAttrs (o: {
        # we don't use shim, so disable the mechanism for it
        postPatch = o.postPatch + ''
            substituteInPlace plugins/uefi-capsule/uefi_capsule.conf \
                --replace "[uefi]" "[uefi_capsule]" \
                --replace "#DisableShimForSecureBoot=true" "DisableShimForSecureBoot=true"
        '';

        # to prevent use of nix as a signing oracle,
        # we pre-sign the fwupd binaries and include the signed efi object blob
        # this is done with the "resign-fwupd-efi.sh" script
        postBuild = lib.optionalString (builtins.pathExists efiBlob) ''
            mkdir -p $out/libexec/fwupd/efi
            cp ${efiBlob} $out/libexec/fwupd/efi/fwupdx64.efi.signed
        '';
    });
}
