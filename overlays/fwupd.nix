final: prev: with prev; {
    fwupd = prev.fwupd.overrideAttrs (o: {
        # we don't use shim, so disable the mechanism for it
        postPatch = o.postPatch + ''
            substituteInPlace plugins/uefi-capsule/uefi_capsule.conf \
                --replace "[uefi]" "[uefi_capsule]" \
                --replace "#DisableShimForSecureBoot=true" "DisableShimForSecureBoot=true"
        '';
    });
}
