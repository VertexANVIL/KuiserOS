{ final, prev, ... }:

# linuxPackages is overridden to 5.10 and our own custom modules are added here
prev.linuxPackages_5_10.extend (finalx: prevx: {
    kernel = prevx.kernel.override {
        kernelPatches = [
            # restores removed mmput_async and kallsyms_lookup exports
            # in order to get some special modules to build (i.e. SGX).
            # these exist in ubuntu and rhel but not mainline
            {
                name = "restore-mmput-kallsyms";
                patch = ./patches/0001-restore-mmput-kallsyms.patch;
            }
        ];
    };
    
    # start of our custom modules
    intel-sgx-dcap = prevx.callPackage ./intel/sgx/dcap { };
    intel-sgx-sgx1 = prevx.callPackage ./intel/sgx/sgx1 { };
})
