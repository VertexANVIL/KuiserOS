{ lib, pkgs, ... }:
{
    # This is a subset of the security hardening configuration present in nixpkgs
    # The goal here is to turn on as many hardening options as we can without sacrificing performance or usability
    nix = {
        useSandbox = true;
        allowedUsers = [ "@wheel" ];
        trustedUsers = [ "root" "@wheel" ];
    };

    # perf test this later to see if it's viable
    # environment = {
    #     memoryAllocator.provider = "scudo";
    #     variables.SCUDO_OPTIONS = "ZeroContents=1";
    # };

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

            # Don't enable this, we want to be able to debug the kernel
            #"kernel.ftrace_enabled" = false;

            # Enable strict reverse path filtering (that is, do not attempt to route
            # packets that "obviously" do not belong to the iface's network; dropped
            # packets are logged as martians).
            "net.ipv4.conf.all.log_martians" = true;
            "net.ipv4.conf.all.rp_filter" = 1;
            "net.ipv4.conf.default.log_martians" = true;
            "net.ipv4.conf.default.rp_filter" = 1;

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
    };

    security = {
        # enable apparmor - not 100% useful yet
        apparmor.enable = true;

        allowSimultaneousMultithreading = true;
        forcePageTableIsolation = true;

        # currently required for polkit to work properly...
        # hideProcessInformation = true;

        # we want to be able to load modules on demand
        # lockKernelModules = true;

        protectKernelImage = true;
        unprivilegedUsernsClone = true;
    };

    services = {
        dbus.apparmor = "enabled";

        usbguard = {
            # enabled on a per-device basis
            enable = lib.mkDefault false;
            package = pkgs.usbguard-nox;
            rules = builtins.readFile ./usbguard.conf;

            IPCAllowedGroups = [ "wheel" ];
        };
    };

    # binary wrapper config is elsewhere
    programs.firejail.enable = true;
}
