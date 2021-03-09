{
    virtualisation.libvirtd = {
        enable = true;
        qemuRunAsRoot = false;
    };

    # IP forwarding is required for libvirt's NAT
    boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
    };
}