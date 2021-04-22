# Install the repository configuration that matches your device operating system
curl https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list > ./microsoft-prod.list

# Copy the generated list to the sources.list.d directory
sudo cp ./microsoft-prod.list /etc/apt/sources.list.d/

# Install the Microsoft GPG public key
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo cp ./microsoft.gpg /etc/apt/trusted.gpg.d/

# Install a container engine
sudo apt-get update
sudo apt-get install moby-engine

<optional>
    curl -sSL https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh -o check-config.sh
    chmod +x check-config.sh
    ./check-config.sh

    => In the output of the script, check that all items under Generally Necessary and Network Drivers are enabled
<optional>

# Install IoT Edge
sudo apt-get update
<optional>
    apt list -a iotedge
<optional>
sudo apt-get install iotedge

# Provision the device with its cloud identity
sudo nano /etc/iotedge/config.yaml
<edit>
    # Manual provisioning configuration using a connection string
    provisioning:
    source: "manual"
    device_connection_string: "<ADD DEVICE CONNECTION STRING HERE>"
<edit>

# Start the Deamon
sudo systemctl restart iotedge

# Verify successful configuration
sudo systemctl status iotedge
journalctl -u iotedge
sudo iotedge check
