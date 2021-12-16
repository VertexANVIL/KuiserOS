#!/usr/bin/env bash
# Updates edge handler state file with new devices

action="$1"
device_in="$2"
config_string=""
STATE_FILE="/var/opt/nfast-edge-handler/devices"
if [ -f "$STATE_FILE" ]; then
    config_string=$(cat "$STATE_FILE")
fi

declare -a old_devices=()
if [ -n "$config_string" ]; then
    # seperate on : into array
    old_devices=("${config_string//:/ }")
fi

# include the new device
if [ "$action" == "insert" ]; then
    old_devices+=("$device_in")
    echo "$device_in found by udev"
fi

# remove duplicates (incase the "new" one was already here)
IFS=" " read -r -a sorted_devices <<< "$(echo "${old_devices[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

# Check the devices are still present
for a in "${sorted_devices[@]}"; do
    if [[ -n "$a" && "$a" != " " && -c "$a" ]]; then
        real_devices+=("$a")
    else
        echo "$a removed from config, no longer attached"
        #So we know a restart is needed
        device_removed=true
    fi
done

# recreate the configuration settings into 1 string
config_string=""
for a in "${real_devices[@]}"; do
    if [ "$config_string" == "" ]; then
        config_string+="$a"
    else
        config_string+=":$a"
    fi
done

echo -n "$config_string" > "$STATE_FILE"

# on insert, the edge takes some time to be ready... wait   
if [ "$1" == "insert" ]; then
    echo "INFO: Waiting for the Edge to be ready: ETA 30 seconds"
    sleep 30
    echo "WARN: Restarting hardserver"
	systemctl restart ncipher-hardserver
	echo "INFO: The hardserver has finished restarting"
    sleep 1
    systemctl restart ncipher-raserv
elif [ "$device_removed" = true ]; then
    echo "WARN: Restarting hardserver"
	systemctl restart ncipher-hardserver
	echo "INFO: The hardserver has finished restarting"
    sleep 1
    systemctl restart ncipher-raserv
fi
