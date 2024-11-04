#!/bin/bash

# ========== CONSTANT VARIABLES ==========

# Define WGDASH if it's not already defined
: "${WGDASH:=/opt/wireguarddashboard}"

# Define CONFIGURATION_PATH if it's not already defined
: "${CONFIGURATION_PATH:=$WGDASH}"

LOG_DIR="${WGDASH}/app/src/log"
PID_FILE="${WGDASH}/app/src/gunicorn.pid"
CONFIG_FILE="${CONFIGURATION_PATH}/wg-dashboard.ini"
PY_CACHE="${WGDASH}/app/src/__pycache__"
WG_CONF_DIR="/etc/wireguard"
INITIAL_SLEEP=5
RETRY_SLEEP=5
venv_python="./venv/bin/python3"

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

# ========== STOP CORE SERVICES ==========
stop_core() {
    echo "Stopping WireGuard Dashboard service."
    . "${WGDASH}/app/src/venv/bin/activate"
    cd "${WGDASH}/app/src" || { echo "Failed to change directory. Exiting."; return; }
    bash wgd.sh stop
}

# ========== SET ENVIRONMENT VARIABLES ==========
set_envvars() {
    echo "Setting environment variables."

    # Update timezone
    if [ "${TZ}" != "$(cat /etc/timezone)" ]; then
        echo "Updating timezone to ${TZ}."
        ln -sf /usr/share/zoneinfo/"${TZ}" /etc/localtime
        echo "${TZ}" > /etc/timezone
    fi

    . "${WGDASH}/app/src/venv/bin/activate"
    cd "${WGDASH}/app/src" || { echo "Failed to change directory. Exiting."; return; }
    ${venv_python} /update_wireguard.py

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
            latestErrLog=$(find "$LOG_DIR" -name "error_*.log" -type f -print | sort -r | head -n 1)
            latestAccLog=$(find "$LOG_DIR"  -name "access_*.log" -type f -print | sort -r | head -n 1)

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

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found, running initial setup..."

    echo "========== START CORE: =========="
    start_core

    echo "Waiting for $INITIAL_SLEEP seconds before stopping core..."
    sleep "$INITIAL_SLEEP"

    echo "========== STOP CORE: ==========="
    stop_core
fi

echo "========== CLEAN UP: ============"
clean_up

echo "========== SET ENV: ============="
set_envvars

echo "========== START CORE: =========="
start_core

echo "========== SHOW LOGS: ==========="
display_logs
