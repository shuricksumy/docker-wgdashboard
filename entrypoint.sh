#!/bin/bash

# Function to clean up remnants of previous instances
clean_up() {
    echo "Starting cleanup process..."
    local pid_file="/opt/wireguarddashboard/app/src/gunicorn.pid"
    
    if [ -f "$pid_file" ]; then
        echo "Found old .pid file. Removing it."
        rm "$pid_file"
    else
        echo "No .pid file found. Continuing."
    fi
}

# Function to start the WireGuard core services
start_core() {
    local wg_conf_file="/etc/wireguard/wg0.conf"
    
    if [ ! -f "$wg_conf_file" ]; then
        cp "/wg0.conf" "$wg_conf_file"
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
            if [ -n "$interface" ]; then
                echo "Bringing up interface: $interface"
                wg-quick up "$interface"
            else
                echo "Interface $interface is not specified, skipping."
            fi
        done
    else
        echo "No interfaces specified in the 'ENABLE' variable."
    fi
}

# Function to update a configuration file with given post-up or post-down commands
update_conf_file() {
    local interface=$1
    local post_up_cmd=$2
    local post_down_cmd=$3
    local conf_file="$WG_CONF_DIR/${interface}.conf"
    local temp_file="${conf_file}.tmp"

    if [ -f "$conf_file" ]; then
        echo "Updating $conf_file with PostUp and PostDown commands."

        # Create a temporary file for edits
        cp "$conf_file" "$temp_file"

        # Replace PostUp command if it exists
        if [ -n "$post_up_cmd" ]; then
            if grep -q "^PostUp" "$temp_file"; then
                sed "s|^PostUp.*|PostUp = $post_up_cmd|" "$temp_file" > "${temp_file}.updated"
                mv "${temp_file}.updated" "$temp_file"
            else
                echo "PostUp command not found in $conf_file."
            fi
        fi

        # Replace PostDown command if it exists
        if [ -n "$post_down_cmd" ]; then
            if grep -q "^PostDown" "$temp_file"; then
                sed "s|^PostDown.*|PostDown = $post_down_cmd|" "$temp_file" > "${temp_file}.updated"
                mv "${temp_file}.updated" "$temp_file"
            else
                echo "PostDown command not found in $conf_file."
            fi
        fi

        # Replace the original file with the updated temporary file
        cp "$temp_file" "$conf_file"
        rm "$temp_file"

    else
        echo "$conf_file not found. Skipping."
    fi
}

# Function to set environment variables and update configuration
set_envvars() {
    echo "Setting environment variables."

    local config_file="/opt/wireguarddashboard/app/src/wg-dashboard.ini"
    local temp_file="${config_file}.tmp"

    # Create a temporary file for edits
    cp "$config_file" "$temp_file"

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
        echo "Public-IP set to: $PUBLIC_IP"
        # Verify the update
        if grep -q "^remote_endpoint = $PUBLIC_IP" "$temp_file"; then
            echo "remote_endpoint updated successfully to $PUBLIC_IP"
        else
            echo "Failed to update remote_endpoint"
        fi
    else
        echo "Public-IP is already set correctly: $current_ip"
    fi

    # Replace the original file with the updated temporary file
    cp "$temp_file" "$config_file"
    rm "$temp_file"

    # Update PostUp and PostDown commands separately
    WG_CONF_DIR="/etc/wireguard"
    for var in $(env | grep -E '^WG[0-9]+_POST_UP=|^WG[0-9]+_POST_DOWN=' | awk -F= '{print $1}'); do
        case $var in
            WG*POST_UP)
                interface=$(echo "$var" | sed -E 's/WG([0-9]+)_POST_UP/\1/')
                post_up_cmd=${!var}
                update_conf_file "wg${interface}" "$post_up_cmd" "" # Only update PostUp
                ;;
            WG*POST_DOWN)
                interface=$(echo "$var" | sed -E 's/WG([0-9]+)_POST_DOWN/\1/')
                post_down_cmd=${!var}
                update_conf_file "wg${interface}" "" "$post_down_cmd" # Only update PostDown
                ;;
        esac
    done

    echo "Configuration update complete."
}

# Function to ensure the container continues running
ensure_blocking() {
    sleep 1s
    echo "Ensuring container continuation."

    local log_dir="/opt/wireguarddashboard/app/src/log"
    if find "$log_dir" -mindepth 1 -maxdepth 1 -type f | read -r; then
        local latestErrLog=$(find "$log_dir" -name "error_*.log" | head -n 1)
        local latestAccLog=$(find "$log_dir" -name "access_*.log" | head -n 1)
        tail -f "$latestErrLog" "$latestAccLog"
    fi

    sleep infinity
}

# Execute the main functions
echo "========== CLEAN UP: ============"
clean_up
echo "========== SET ENV: ============="
set_envvars
echo "========== START CORE: =========="
start_core
echo "========== CHECK BLOCKING: ======"
ensure_blocking
