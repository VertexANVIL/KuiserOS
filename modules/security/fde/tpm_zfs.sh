#!/usr/bin/env bash
# Copyright 2020 Alex Zero

wrap_key() {
    echo "Please enter the volume key"
    read -s -p "Key: " KEY && echo -e "\n"

    if [ -z "$KEY" ]; then
        # key is blank, so generate one
        echo "No key passed, generating a key..."
        KEY=$(pwgen -s 64 1)
    fi

    echo "Wrapping key..."
    tpm_nvdefine -i 1 -s "$(echo -n "$KEY" | wc -c)" -p "OWNERWRITE|READ_STCLEAR" -y -r0 -r1 -r2 -r3 -r4 -r8 -r9 -r12 && \
    tpm_nvwrite -i 1 -d "$KEY" -z
    if [ $? -ne 0 ]; then
        echo "Failed to define the TPM register."
        exit 1
    fi

    echo -n "Readback test..."
    RBKEY=$(tpm_nvread -i 1 | awk '{ ORS=""; print $NF; }')
    if [ $? -ne 0 -o "$RBKEY" != "$KEY" ]; then
        echo " FAILED."
        exit 1
    fi

    echo " PASSED."
}

destroy_key() {
    tpm_nvrelease -i 1 -y
    if [ $? -ne 0 ]; then
        echo "Failed to clear TPM register. STOP"
        exit 1
    fi
}

unlock_volume() {
    ZPATH=$1
    KEY=$2

    VOLGUID=$(zfs get guid -o value -H $ZPATH)
    RAW=$(tpm_nvread -i 1)
    if [ $? -ne 0 ]; then
        echo "Couldn't read the secret from the TPM. STOP"
        exit 1
    fi

    KEY=$(echo "$RAW" | awk '{ ORS=""; print $NF; }')
    echo "$KEY" | zfs load-key $ZPATH

    if [ $? -ne 0 ]; then
        echo "Failed to unlock the volume with the provided key. STOP"
        exit 1
    fi

    # prevent any further reading
    tpm_nvread -i 1 -s 0 >> /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to lock the register after reading. STOP"
        exit 1
    fi

    echo "Volume has been unlocked."
    zfs mount "$ZPATH"
}

case $1 in
    unlock)
        if [ -z "$2" -o -z "$3" ]; then
            echo "No pool name or volume name passed!"
            exit 1
        fi

        POOL=$2
        VOLUME=$3
        ZPATH="$POOL/$VOLUME"

        echo "Pool name: $POOL"
        echo "Volume name: $VOLUME"
        echo ""

        if [ "$(zfs get encryption -o value -H "$ZPATH")" = "off" ]; then
            echo "Encryption is disabled on volume $ZPATH"
            exit 1
        fi

        unlock_volume "$ZPATH" "$KEY"
        ;;
    wrapkey)
        wrap_key
        ;;
    destroykey)
        destroy_key
        ;;
    --)
        ;;
esac
