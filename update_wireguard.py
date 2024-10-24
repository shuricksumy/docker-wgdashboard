import os
import configparser

WG_CONFIG_DIR = "/etc/wireguard"
SCRIPTS_DIR = "/scripts"
WGDASH = os.getenv('WGDASH','/opt/wireguarddashboard')
APP_CONFIG_FILE = os.path.join(WGDASH, 'app/src/app_conf/wg-dashboard.ini')

# Custom ConfigParser to handle case sensitivity
class CaseSensitiveConfigParser(configparser.ConfigParser):
    def optionxform(self, optionstr):
        return optionstr


# Function to check if a script exists for a specific interface and command (PreUp, PreDown, PostUp, PostDown)
def get_script_path(interface_name, command):
    script_file = f"{interface_name}_{command}.sh"
    script_path = os.path.join(SCRIPTS_DIR, script_file)
    if os.path.exists(script_path):
        return f"/bin/bash {script_path}"
    return ""


# Function to handle the interface section separately
def update_conf_file(interface_name):
    conf_file = os.path.join(WG_CONFIG_DIR, f"{interface_name}.conf")

    if not os.path.exists(conf_file):
        print(f"Config file for {interface_name} does not exist.")
        return

    # Step 1: Read the entire file as a list of lines
    with open(conf_file, 'r') as file:
        lines = file.readlines()

    # Step 2: Extract the [Interface] section using the custom case-sensitive configparser
    config = CaseSensitiveConfigParser(allow_no_value=True, strict=False)

    interface_lines = []
    peer_lines = []
    inside_interface = False
    inside_peer = False

    for line in lines:
        if "[Interface]" in line:
            inside_interface = True
            inside_peer = False
            interface_lines.append(line)
        elif "[Peer]" in line:
            inside_interface = False
            inside_peer = True
            peer_lines.append(line)
        elif inside_interface:
            interface_lines.append(line)
        elif inside_peer or not inside_interface:
            peer_lines.append(line)

    # Step 3: Load the interface section into configparser and modify it
    config.read_string(''.join(interface_lines))

    # Modify the [Interface] parameters
    pre_up = get_script_path(interface_name, "pre_up")
    pre_down = get_script_path(interface_name, "pre_down")
    post_up = get_script_path(interface_name, "post_up")
    post_down = get_script_path(interface_name, "post_down")

    # Update or add these values in the [Interface] section
    config['Interface']['PreUp'] = pre_up
    config['Interface']['PreDown'] = pre_down
    config['Interface']['PostUp'] = post_up
    config['Interface']['PostDown'] = post_down

    # Step 4: Write the updated config back
    with open(conf_file, 'w') as file:
        # Write the updated [Interface] section
        config.write(file)

        # Append the rest of the file (the [Peer] sections)
        for peer_line in peer_lines:
            file.write(peer_line)

    print(f"Updated {conf_file}")


# Function to process all interface configs
def process_interfaces():
    # Get all .conf files from the WireGuard config directory
    for conf_file in os.listdir(WG_CONFIG_DIR):
        if conf_file.endswith(".conf"):
            interface_name = conf_file.replace(".conf", "")
            print(f"Processing {interface_name}")
            update_conf_file(interface_name)


# Function to update wg-dashboard.ini based on environment variables
def update_app_config():
    config = configparser.ConfigParser(allow_no_value=True,strict=False)
    config.optionxform = str  # Make option names case-sensitive

    if not os.path.exists(APP_CONFIG_FILE):
        print(f"App config file {APP_CONFIG_FILE} does not exist.")
        return

    # Read the app config file
    try:
        with open(APP_CONFIG_FILE, 'r') as file:
            config.read_file(file)
    except Exception as e:
        print(f"Error reading {APP_CONFIG_FILE}: {e}")
        return

    # Update [Peers] section for GLOBAL_DNS and PUBLIC_IP
    global_dns = os.getenv('GLOBAL_DNS')
    public_ip = os.getenv('PUBLIC_IP')

    if 'Peers' not in config:
        print(f"[Peers] section missing in {APP_CONFIG_FILE}")
        return

    if global_dns is not None:
        print(f"Setting GLOBAL_DNS: {global_dns}")
        config['Peers']['peer_global_dns'] = global_dns

    if public_ip is not None:
        print(f"Setting PUBLIC_IP: {public_ip}")
        config['Peers']['remote_endpoint'] = public_ip

    # Update [Server] section for APP_PREFIX
    app_prefix = os.getenv('APP_PREFIX', '')

    if 'Server' not in config:
        print(f"[Server] section missing in {APP_CONFIG_FILE}")
        return

    print(f"Setting APP_PREFIX: {app_prefix}")
    config['Server']['app_prefix'] = app_prefix

    # Write the changes back to the config file
    try:
        with open(APP_CONFIG_FILE, 'w') as configfile:
            config.write(configfile)
        print(f"Updated {APP_CONFIG_FILE}")
    except Exception as e:
        print(f"Error writing {APP_CONFIG_FILE}: {e}")

if __name__ == "__main__":
    process_interfaces()  # Update WireGuard interface configs
    update_app_config()  # Update wg-dashboard.ini based on environment variables
