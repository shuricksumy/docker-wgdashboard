#!/bin/bash

# ========== CONSTANT VARIABLES ==========

# Define WGDASH if it's not already defined
: "${WGDASH:=/opt/wireguarddashboard}"

LOG_DIR="${WGDASH}/app/src/log"
PID_FILE="${WGDASH}/app/src/gunicorn.pid"
WG_CONF_FILE="/etc/wireguard/wg0.conf"
DEFAULT_WG_CONF="/wg0.conf"
CONFIG_FILE="${CONFIGURATION_PATH}/wg-dashboard.ini"
PY_CACHE="${WGDASH}/app/src/__pycache__"
WG_CONF_DIR="/etc/wireguard"
INITIAL_SLEEP=5
RETRY_SLEEP=5

# ========== CLEAN UP ==========
clean_up() {
    echo "Starting cleanup process..."

    if [ -f "$PID_FILE" ]; then
        echo "Found old .pid file. Removing it."
        rm "$PID_FILE"
    else
        echo "No .pid file found. Continuing."
    fi

    if [ -d "$PY_CACHE" ]; then
        echo "Directory $PY_CACHE exists. Deleting it..."
        rm -rf "$PY_CACHE"
        echo "Python cache directory deleted."
    fi

}

# ========== START CORE SERVICES ==========
start_core() {
    if [ ! -f "$WG_CONF_FILE" ]; then
        cp "$DEFAULT_WG_CONF" "$WG_CONF_FILE"
        echo "WireGuard interface file copied."
    else
        echo "WireGuard interface file already exists."
    fi

    echo "Activating Python virtual environment and starting WireGuard Dashboard service."
    . "${WGDASH}/app/src/venv/bin/activate"
    cd "${WGDASH}/app/src" || { echo "Failed to change directory. Exiting."; return; }
    bash wgd.sh start

    if [ -n "$ENABLE" ]; then
        IFS=',' read -r -a interfaces <<< "$ENABLE"
        for interface in "${interfaces[@]}"; do
            echo "Bringing up interface: $interface"
            wg-quick up "$interface"
        done
    else
        echo "No interfaces specified in the 'ENABLE' variable."
    fi
}

# ========== UPDATE CONFIGURATION FILE ==========
update_conf_file() {
    local interface=$1
    local post_up_cmd=$2
    local post_down_cmd=$3
    local conf_file="$WG_CONF_DIR/${interface}.conf"
    local temp_file="${conf_file}.tmp"

    if [ -f "$conf_file" ]; then
        echo "Updating $conf_file with PostUp and PostDown commands."
        cp "$conf_file" "$temp_file"

        # Update PostUp command
        if [ -n "$post_up_cmd" ] && grep -q "^PostUp" "$temp_file"; then
            sed "s|^PostUp.*|PostUp = $post_up_cmd|" "$temp_file" > "${temp_file}.updated"
            mv "${temp_file}.updated" "$temp_file"
        fi

        # Update PostDown command
        if [ -n "$post_down_cmd" ] && grep -q "^PostDown" "$temp_file"; then
            sed "s|^PostDown.*|PostDown = $post_down_cmd|" "$temp_file" > "${temp_file}.updated"
            mv "${temp_file}.updated" "$temp_file"
        fi

        cp "$temp_file" "$conf_file"
        rm "$temp_file"
    else
        echo "$conf_file not found. Skipping."
    fi
}

# ========== SET ENVIRONMENT VARIABLES ==========
set_envvars() {
    echo "Setting environment variables."
    local temp_file="${CONFIG_FILE}.tmp"
    cp "$CONFIG_FILE" "$temp_file"

    # Update timezone
    if [ "${TZ}" != "$(cat /etc/timezone)" ]; then
        echo "Updating timezone to ${TZ}."
        ln -sf /usr/share/zoneinfo/"${TZ}" /etc/localtime
        echo "${TZ}" > /etc/timezone
    fi

    # Update DNS
    local current_dns=$(grep "peer_global_dns =" "$temp_file" | awk '{print $NF}')
    if [ "${GLOBAL_DNS}" != "$current_dns" ]; then
        echo "Updating DNS to ${GLOBAL_DNS}."
        sed "s/^peer_global_dns = .*/peer_global_dns = ${GLOBAL_DNS}/" "$temp_file" > "${temp_file}.updated"
        mv "${temp_file}.updated" "$temp_file"
    fi

    # Update public IP
    local current_ip=$(grep "remote_endpoint =" "$temp_file" | cut -d'=' -f2 | tr -d ' ')
    if [ "$PUBLIC_IP" = "0.0.0.0" ]; then
        PUBLIC_IP=$(curl -s ifconfig.me)
        echo "Fetched Public-IP using ifconfig.me: $PUBLIC_IP"
    fi
    if [ "$PUBLIC_IP" != "$current_ip" ]; then
        sed "s/^remote_endpoint = .*/remote_endpoint = $PUBLIC_IP/" "$temp_file" > "${temp_file}.updated"
        mv "${temp_file}.updated" "$temp_file"
    fi

    # Update app_prefix
    local current_prefix=$(grep "app_prefix =" "$temp_file" | awk '{print $NF}')
    if [ "$APP_PREFIX" != "$current_prefix" ]; then
        sed -i "s|^app_prefix =.*|app_prefix = $APP_PREFIX|" "$temp_file"
    fi

    cp "$temp_file" "$CONFIG_FILE"
    rm "$temp_file"

    # Update PostUp and PostDown commands for interfaces
    for var in $(env | grep -E '^WG[0-9]+_POST_UP=|^WG[0-9]+_POST_DOWN=' | awk -F= '{print $1}'); do
        interface=$(echo "$var" | sed -E 's/WG([0-9]+)_.*/\1/')
        if [[ $var == *POST_UP* ]]; then
            update_conf_file "wg${interface}" "${!var}" ""
        elif [[ $var == *POST_DOWN* ]]; then
            update_conf_file "wg${interface}" "" "${!var}"
        fi
    done

    echo "Configuration update complete."
}

# ========== DISPLAY LOGS ==========
display_logs() {
    echo "Waiting for $INITIAL_SLEEP seconds to ensure logs are created..."
    sleep "$INITIAL_SLEEP"

    while true; do
        echo "Checking for latest logs..."

        # Check if log directory is not empty
        if find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type f | read -r; then
            latestErrLog=$(find "$LOG_DIR" -name "error_*.log" -type f -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2- | head -n 1)
            latestAccLog=$(find "$LOG_DIR" -name "access_*.log" -type f -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2- | head -n 1)

            # Tail the latest error and access logs
            if [[ -n "$latestErrLog" && -n "$latestAccLog" ]]; then
                echo "Tailing logs: $latestErrLog, $latestAccLog"
                tail -f "$latestErrLog" "$latestAccLog"
            else
                echo "No logs found to tail."
            fi
        else
            echo "Log directory is empty."
        fi

        echo "Retrying in $RETRY_SLEEP seconds..."
        sleep "$RETRY_SLEEP"
    done
}

# ========== MAIN EXECUTION ==========
echo "========== CLEAN UP: ============"
clean_up

echo "========== SET ENV: ============="
set_envvars

echo "========== START CORE: =========="
start_core

echo "========== SHOW LOGS: ==========="
display_logs
