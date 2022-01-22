#!/usr/bin/env bash
# Initialises the nfast services

function mkdir_safe {
    test -d "$3" || mkdir "$3"
    chown "$1:$2" "$3"
}

function mkdir__s_rwxrwxr_x {
    us="$1"
	shift
	gr="$1"
	shift

    for d in "$@"; do
        mkdir_safe "$us" "$gr" "$d"
        chmod 2775 "$d"
    done
}

function mkdir__s_rwxr_xr_x {
    us="$1"
	shift
	gr="$1"
	shift

    for d in "$@"; do
        mkdir_safe "$us" "$gr" "$d"
        chmod 2755 "$d"
    done
}

function mkdir__s_rwxr_x___ {
    us="$1"
	shift
	gr="$1"
	shift

    for d in "$@"; do
        mkdir_safe "$us" "$gr" "$d"
        chmod 2750 "$d"
    done
}

function mkdir___trwxrwxrwx {
    us="$1"
	shift
	gr="$1"
	shift

    for d in "$@"; do
        mkdir_safe "$us" "$gr" "$d"
        chmod 1777 "$d"
    done
}

function mkdir____rwx______ {
    us="$1"
	shift
	gr="$1"
	shift

    for d in "$@"; do
        mkdir_safe "$us" "$gr" "$d"
        chmod 0700 "$d"
    done
}

function render_config() {
    CARDLIST="$NFAST_HOME/kmdata/config/cardlist"
    CONFIG="$NFAST_HOME/kmdata/config/config"
    rm -rf "$CARDLIST" "$CONFIG"
    cp "$NFAST_CARDLIST_SOURCE" "$CARDLIST"
    cp "$NFAST_CONFIG_SOURCE" "$CONFIG"
    chmod 0644 "$CARDLIST" "$CONFIG"

    state_string=""
    state_file="/var/opt/nfast-edge-handler/devices"
    if [ -f "$state_file" ]; then
        state_string=$(cat "$state_file")
    fi

    # this requires serial_dtpp_devices=
    current_config=$(grep "serial_dtpp_devices=" "$CONFIG")
    config_string="serial_dtpp_devices=$state_string"
    escaped_config_string=$(echo "$config_string" | sed -e 's/[]\/$*.^|[]/\\&/g')
    escaped_current_config=$(echo "$current_config" | sed -e 's/[]\/$*.^|[]/\\&/g')
    sed -i 's/'"$escaped_current_config"'/'"$escaped_config_string"'/' "$CONFIG"

    echo "$current_config"

    # make the config file readonly
    chmod 0555 "$CONFIG"
}

# Set up directories
if [ -d "$NFAST_HOME/kmdata/hardserver.d/" ] && [ ! -d "$NFAST_HOME/hardserver.d/" ];
then
  echo "Upgrade: moving hardserver.d to new location"
  mv "$NFAST_HOME/kmdata/hardserver.d" "$NFAST_HOME/"
fi

# Create directories
mkdir__s_rwxrwxr_x 0 0 "$NFAST_HOME/log"

mkdir__s_rwxr_xr_x "$NFAST_USER" "$NFAST_GROUP" "$NFAST_HOME/sockets"
mkdir__s_rwxr_x___ "$NFAST_USER" "$NFAST_GROUP" "$NFAST_HOME/sockets/priv"
mkdir____rwx______ "$NFAST_USER" "$NFAST_GROUP" "$NFAST_HOME/hardserver.d"
mkdir__s_rwxrwxr_x "$NFAST_USER" "$NFAST_GROUP" \
    "$NFAST_HOME/kmdata" "$NFAST_HOME/kmdata/local" "$NFAST_HOME/kmdata/config" "$NFAST_HOME/kmdata/tmp" \
    "$NFAST_HOME/kmdata/features" "$NFAST_HOME/kmdata/warrants" "$NFAST_HOME/custom-seemachines" \
    "$NFAST_HOME/services" "$NFAST_HOME/services/client" "$NFAST_HOME/services/module"

# Create backwards compat sockets
ln -s "$NFAST_HOME/sockets" "/dev/nfast" > /dev/null 2>&1

# Create default cardlist file
cardlist="$NFAST_HOME/kmdata/config/cardlist"
mkcardlist="$NFAST_HOME/bin/cfg-mkcardlist"

if [ ! -f "$cardlist" ] && [ -x "$mkcardlist" ]; then
    "$mkcardlist" -f "$cardlist"
    chown nfast "$cardlist"
    chown nfast "$cardlist"
    chmod 0644 "$cardlist"
fi

# Enforce KNETI file permissions on existing KNETI files so they are not too loose
if [ -d "$NFAST_HOME/hardserver.d/" ]
then
  for f in "${NFAST_HOME}"/hardserver.d/kneti-*; do
    if [ -f "${f}" ]
    then
      echo "Enforcing kneti file permissions on ${f}"
      chown nfast:nfast "${f}"
      chmod 600 "${f}"
    fi
  done
fi

# Render the configuration
render_config
