{ final, prev, ... }:

# linuxPackages is overridden to 5.12 and our own custom modules are added here
prev.linuxPackages.extend (finalx: prevx: {
    # start of our custom modules
    # intel-sgx-dcap = prevx.callPackage ./intel/sgx/dcap { };
    # intel-sgx-sgx1 = prevx.callPackage ./intel/sgx/sgx1 { };
})
