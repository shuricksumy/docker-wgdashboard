#!/bin/bash
echo "Starting the WireGuard Dashboard Docker container."

clean_up() {
  # Cleaning out previous data such as the .pid file and starting the WireGuard Dashboard. Making sure to use the python venv.
  echo "Looking for remains of previous instances..."
  if [ -f "/opt/wireguarddashboard/app/src/gunicorn.pid" ]; then
    echo "Found old .pid file, removing."
    rm /opt/wireguarddashboard/app/src/gunicorn.pid
  else
    echo "No remains found, continuing."
  fi
}

start_core() {
  # This first step is to ensure the wg0.conf file exists, and if not, then its copied over from the ephemeral container storage.
  if [ ! -f "/etc/wireguard/wg0.conf" ]; then
    cp "/wg0.conf" "/etc/wireguard/wg0.conf"
    echo "WireGuard interface file copied over."
  else
    echo "WireGuard interface file looks to already be existing."
  fi
  
  echo "Activating Python venv and executing the WireGuard Dashboard service."

  . "${WGDASH}"/venv/bin/activate
  cd "${WGDASH}"/app/src || return # If changing the directory fails (permission or presence error), then bash will exist this function, causing the WireGuard Dashboard to not be succesfully launched.
  bash wgd.sh start

  # Check if the enable variable is not empty
  if [ -n "$enable" ]; then
    # Convert the comma-separated list into an array
    IFS=',' read -r -a interfaces <<< "$enable"

    # Loop through each interface in the array
    for interface in "${interfaces[@]}"; do
      if [ ! -z "$interface" ]; then
        echo "Bringing up interface: $interface"
        wg-quick up "$interface"
      else
        echo "Interface $interface is not specified, skipping."
      fi
    done
  else
    echo "No interfaces specified in the 'enable' variable."
  fi
}

# Function to update a configuration file with given post-up and post-down commands
update_conf_file() {
    local interface=$1
    local post_up_cmd=$2
    local post_down_cmd=$3
    local conf_file="$WG_CONF_DIR/${interface}.conf"

    if [ -f "$conf_file" ]; then
        echo "Updating $conf_file with PostUp and PostDown commands."

        # Replace PostUp command if it exists
        if [ -n "$post_up_cmd" ]; then
            if grep -q "^PostUp" "$conf_file"; then
                sed -i "s|^PostUp.*|PostUp = $post_up_cmd|" "$conf_file"
            fi
        fi

        # Replace PostDown command if it exists
        if [ -n "$post_down_cmd" ]; then
            if grep -q "^PostDown" "$conf_file"; then
                sed -i "s|^PostDown.*|PostDown = $post_down_cmd|" "$conf_file"
            fi
        fi
    else
        echo "$conf_file not found. Skipping."
    fi
}


set_envvars() {
  echo "Setting relevant variables for operation."

  # If the timezone is different, for example in North-America or Asia.
  if [ "${tz}" != "$(cat /etc/timezone)" ]; then
    echo "Changing timezone."
    
    ln -sf /usr/share/zoneinfo/"${tz}" /etc/localtime
    echo "${tz}" > /etc/timezone
  fi

  # Changing the DNS used for clients and the dashboard itself.
  if [ "${global_dns}" != "$(grep "peer_global_dns = " /opt/wireguarddashboard/app/src/wg-dashboard.ini | awk '{print $NF}')" ]; then 
    echo "Changing default dns."

    #sed -i "s/^DNS = .*/DNS = ${global_dns}/" /etc/wireguard/wg0.conf # Uncomment if you want to have DNS on server-level.
    sed -i "s/^peer_global_dns = .*/peer_global_dns = ${global_dns}/" /opt/wireguarddashboard/app/src/wg-dashboard.ini
  fi

  # Setting the public IP of the WireGuard Dashboard container host. If not defined, it will trying fetching it using a curl to ifconfig.me.
  if [ "${public_ip}" = "0.0.0.0" ]; then
    default_ip=$(curl -s ifconfig.me)
    echo "Trying to fetch the Public-IP using ifconfig.me: ${default_ip}"

    sed -i "s/^remote_endpoint = .*/remote_endpoint = ${default_ip}/" /opt/wireguarddashboard/app/src/wg-dashboard.ini
  elif [ "${public_ip}" != "$(grep "remote_endpoint = " /opt/wireguarddashboard/app/src/wg-dashboard.ini | awk '{print $NF}')" ]; then
    echo "Setting the Public-IP using given variable: ${public_ip}"

    sed -i "s/^remote_endpoint = .*/remote_endpoint = ${public_ip}/" /opt/wireguarddashboard/app/src/wg-dashboard.ini
  fi


  # Path to WireGuard configuration files
  WG_CONF_DIR="/etc/wireguard"
  # Iterate over environment variables that match the pattern for PostUp and PostDown
  for var in $(env | grep -E '^WG[0-9]+_POST_UP=|^WG[0-9]+_POST_DOWN=' | awk -F= '{print $1}'); do
      case $var in
          WG*POST_UP)
              # Extract the interface name from the environment variable name
              interface=$(echo "$var" | sed -E 's/WG([0-9]+)_POST_UP/\1/')
              post_up_cmd=${!var}
              # Find corresponding PostDown variable
              post_down_var="WG${interface}_POST_DOWN"
              post_down_cmd=${!post_down_var}
              update_conf_file "wg${interface}" "$post_up_cmd" "$post_down_cmd"
              ;;
          *)
              # Ignore variables that do not match the pattern
              ;;
      esac
  done

  echo "Configuration update complete."
}

ensure_blocking() {
  sleep 1s
  echo "Ensuring container continuation."

  # This function checks if the latest error log is created and tails it for docker logs uses.
  if find "/opt/wireguarddashboard/app/src/log" -mindepth 1 -maxdepth 1 -type f | read -r; then
    latestErrLog=$(find /opt/wireguarddashboard/app/src/log -name "error_*.log" | head -n 1)
    latestAccLog=$(find /opt/wireguarddashboard/app/src/log -name "access_*.log" | head -n 1)
    tail -f "${latestErrLog}" "${latestAccLog}"
  fi

  # Blocking command in case of erroring. So the container does not quit.
  sleep infinity
}

# Execute functions for the WireGuard Dashboard services, then set the environment variables
clean_up
start_core
set_envvars
ensure_blocking