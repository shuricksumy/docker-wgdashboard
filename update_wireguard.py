import os
import configparser

WGDASH = os.getenv('WGDASH','/opt/wireguarddashboard')
APP_CONFIG_FILE = os.path.join(WGDASH, 'app/src/app_conf/wg-dashboard.ini')

# Custom ConfigParser to handle case sensitivity
class CaseSensitiveConfigParser(configparser.ConfigParser):
    def optionxform(self, optionstr):
        return optionstr


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
    update_app_config()  # Update wg-dashboard.ini based on environment variables
