{ lib, pkgs, ... }: let
    inherit (lib) mkDefault;
in {
    # This is a subset of the security hardening configuration present in nixpkgs
    # The goal here is to turn on as many hardening options as we can without sacrificing performance or usability
    nix = {
        useSandbox = true;
        allowedUsers = [ "@users" ];
        trustedUsers = [ "root" "@wheel" ];
    };

    networking.firewall = {
        # don't allow ping by default (for routers, it's overridden in their templates)
        allowPing = lib.mkDefault false;

        # Enable strict reverse path filtering (that is, do not attempt to route
        # packets that "obviously" do not belong to the iface's network; dropped
        # packets are logged as martians).
        checkReversePath = mkDefault true;

        # prevent spam
        logRefusedConnections = lib.mkDefault false;
    };

    environment = {
        memoryAllocator.provider = "scudo";
        variables.SCUDO_OPTIONS = "ZeroContents=1";
    };

    boot = {
        blacklistedKernelModules = [
            # Obscure network protocols
            "ax25" "netrom" "rose"

            # Old or rare or insufficiently audited filesystems
            # NTFS is intentionally not here, we need that
            "adfs" "affs" "bfs" "befs" "cramfs" "efs" "erofs" "exofs"
            "freevxfs" "f2fs" "hfs" "hpfs" "jfs" "minix" "nilfs2"
            "omfs" "qnx4" "qnx6" "sysv" "ufs"
        ];

        kernel.sysctl = {
            # Restrict ptrace() usage to processes with a pre-defined relationship (e.g., parent/child)
            "yama.ptrace_scope" = 1;

            # Hide kptrs even for processes with CAP_SYSLOG
            "kernel.kptr_restrict" = 2;

            # Disable bpf() JIT (to eliminate spray attacks)
            "net.core.bpf_jit_enable" = mkDefault false;

            # Disable ftrace by default, restricting kernel debugging
            "kernel.ftrace_enabled" = mkDefault false;

            # Enable strict reverse path filtering (that is, do not attempt to route
            # packets that "obviously" do not belong to the iface's network; dropped
            # packets are logged as martians).
            "net.ipv4.conf.all.log_martians" = mkDefault true;
            "net.ipv4.conf.all.rp_filter" = mkDefault "1";
            "net.ipv4.conf.default.log_martians" = mkDefault true;
            "net.ipv4.conf.default.rp_filter" = mkDefault "1";

            # Ignore broadcast ICMP (mitigate SMURF)
            "net.ipv4.icmp_echo_ignore_broadcasts" = true;

            # Ignore incoming ICMP redirects (note: default is needed to ensure that the
            # setting is applied to interfaces added after the sysctls are set)
            "net.ipv4.conf.all.accept_redirects" = false;
            "net.ipv4.conf.all.secure_redirects" = false;
            "net.ipv4.conf.default.accept_redirects" = false;
            "net.ipv4.conf.default.secure_redirects" = false;
            "net.ipv6.conf.all.accept_redirects" = false;
            "net.ipv6.conf.default.accept_redirects" = false;

            # Ignore outgoing ICMP redirects (this is ipv4 only)
            "net.ipv4.conf.all.send_redirects" = false;
            "net.ipv4.conf.default.send_redirects" = false;
        };

        kernelPackages = pkgs.linuxPackages_hardened;

        kernelParams = [
            # Slab/slub sanity checks, redzoning, and poisoning
            "slub_debug=FZP"

            # Overwrite free'd memory
            "page_poison=1"

            # Enable page allocator randomization
            "page_alloc.shuffle=1"
        ];
    };

    security = {
        # enable apparmor - not 100% useful yet
        apparmor = {
            enable = true;
            killUnconfinedConfinables = true;
        };

        # enable auditing
        auditd.enable = true;

        # causes a serious performance hit
        # allowSimultaneousMultithreading = false;

        forcePageTableIsolation = true;

        # we want to be able to load modules on demand
        # lockKernelModules = true;

        protectKernelImage = true;
        unprivilegedUsernsClone = true;

        virtualisation.flushL1DataCache = "always";
    };

    services = {
        # enable dbus apparmor
        dbus.apparmor = "enabled";
    };
}
