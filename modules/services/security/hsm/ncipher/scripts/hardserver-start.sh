#!/usr/bin/env bash
set -e

function probe_pci_devices() {
    # Probe for PCI devices
    minor=0
    rm -f /dev/nfastpci*
    set +e
    n=$(lspci -n | grep -E -c "(8086:b555)|(1011:1065)")
    set -e
    # shellcheck disable=2003
    n=$(expr "$n" + 1)
    while test "$n" -gt 1
    do
        dev=/dev/nfastpci$minor
        mknod -m 000 $dev c 176 $minor
        chown nfast:nfast $dev
        chmod 0660 $dev
        nfpdevices="$nfpdevices:$dev"
        # shellcheck disable=2003
        minor=$(expr $minor + 1)
        # shellcheck disable=2003
        n=$(expr "$n" - 1)
    done
}

probe_pci_devices

# shellcheck disable=2001
#nfpdevices="$(echo "$nfpdevices" | sed 's/^://g')"

# Probe for exard devices? Is this required for us?

# All the uses of udevadm here are guarded because they may fail,
# but generally in other people's scripts and so not in ways we
# care about enough to halt installation.

# /sbin/udevadm control --reload || true
# /sbin/udevadm trigger --attr-match=vendor=0x13a8 \
# --attr-match=device=0x0152 --attr-match=subsystem_vendor=0x0100 || true
# /sbin/udevadm trigger --subsystem-match=tty || true
# /sbin/udevadm settle --timeout=30 || true

umask 027
cd "$NFAST_HOME/log"
export PATH="$NFAST_HOME/bin:$PATH"
exec "$NFAST_HOME/sbin/hardserver"
