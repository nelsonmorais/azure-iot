# Azure IoT Sandbox

## Description
The purpose of this project is to create a Sandbox of an Industrial IoT environment by creating a set of Azure resources for that purpose.

The repository contains a set of bash (.azcli) scripts that, once executed, will create a set of Azure IoT related resources.

Once the execution of the scripts ends, an Azure IoT Edge simulator device sending simulated telemetry to an IoT Hub should be up and running. The data should be visible in Time Series Insights and on the storage account to where the raw messages are routed to.

_This is a work in progress and the list of created resources will be adjusted over time._

## What will be created
The scripts will create the following resources:
- 1 Resource group (resource group where all the resources will be created)
- 2 VNets (IT and OT see details below)
  - IT Subnets: Default, AzureBastionSubnet
  - OT Subnets: Default
- 1 Bastion (to provide secure access to the VM of the simulated IoT Edge device)
- Storage Account(s) for:
  - IoT Hub (for custom routing to cold storage)
  - TSI
- 1 Azure Container Registry (to store the IoT Edge simulated temperature module)
  - Private Endpoint + NIC on the IT Default Subnet
  - Image azureiotedge-simulated-temperature-sensor:1.0 pushed to the ACR
- 1 IoT Hub (to where the IoT Edge simulated device will be registered)
  - Private Endpoint + NIC on the IT Default Subnet
- 1 Device Provisioning Service (to provide an enrollment group from where the IoT Edge device will be provisioned)
  - Private Endpoint + NIC on the IT Default Subnet
- [TODO]: Private DNS Zones, linked to the OT (and IT if needed) VNet, with A records for all resources with an IP linked to the NIC of the Private Endpoints
- 1 Ubuntu 18.04 Virtual Machine (the IoT Edge simulated device)
- Time Series Insights
- [TODO]: Azure Streaming Analytics Cluster

## Pre-requisites:
- An Azure Subscription where to run this script
- Script execution on a linux based shell (e.g. Ubuntu on WSL2)
- jq installed (apt-get install jq)
- openssl installed
- Docker (if pull/push images to ACR, see script `acr-push-images.azcli`)
- AzCli extension(s) needed:
  - azure-iot
  - timeseriesinsights

## How to use the scripts
Open a bash shell, clone this repo and create the `variables-local-only.azcli` (see details below), execute the `setup-bash-files.sh` and then the `create-all.azcli` to create all the resources.

Comment parts of the `create-all.azcli` to avoid the creation of all the resources mentioned above. Note that further adjustments might be needed to other scripts to ensure that all dependincies are managed in this case.

The `variables.azcli` is where all the variables are defined. Among others this script specifies the names of all the resources that will be created and these can be adjusted as needed. 

To remove all resources execute the `remove-all.azcli`, see details below regarding resources that might need to be deleted manually.

## Script files details
- `create-all.zcli`: Creates all resources by invoking the individual scripts per resource type
- `remove-all`: Removes all created resources by deleting the resource group where the resources where created. Note that the `NetworkWatcherRG` is not removed has might be present on the Subscription due to other needs, it needs to be removed manually if there're no other identified dependencies
- `bash-functions.azcli`: Utility functions used by the scripts
- `variables-local-only.azcli`: This file is excluded from git and needs to be created to define the following variables
  - SUBSCRIPTION
  - VM_EDGE_ADMIN_USER
  - VM_EDGE_ADMIN_PASS
- `variables.azcli`: All the variables needed to run this script, values can be adjusted as needed on this file
- `vnets.azcli`: Creates the VNets (see more info below)
- `bastion.azcli`: Creates the Bastion to provide access to the VM(s)
- `acr.azcli`: Creates the Azure Container Registry, ACR Private Endpoint
- `acr-push-images`: Pulls / Tag / Pushes the docker images from public registeries to the ACR created here, the images are used by the IoT Edge simulator device
- `iothub.azcli`: Creates the Azure IoT Hub, IoTHub Private Endpoint, configures the Edge deployments of the system and simulated temperature modules, and configures custom routes to a storage account and to the built-in events endpoint
- `dps.azcli`: Creates the Azure Device Provisioning Service, DPS Private Endpoint, configures the linked Iot Hub and sets up an Enrollment Group
- `vm-edge-simulator.azcli`: Creates the VM to simulate the IoT Edge device
- `tsi.azcli`: Creates the Time Series Insigths, configures the IoT Hub consumer group for TSI and adds the IoT Hub as an event source for TSI

## Other files details
- `readme.md`: This file
- `setup-bash-files.sh`: To call `chmod` on all `.azcli` files
- `cloud-config\`
  - `vm-edge-simulator-custom-data.txt`: Cloud config file used to setup the IoT Edge simulator on the first boot of the VM that simulates the Edge device
- `edge-deployment-manifests\`
  - `manifest-system-modules.template`: Template file to be used to create the manifest-system-modules.json file with the proper values
  - `manifest-system-modules.json`: Generated file from the manifest-system-modules.template, can be safely deleted and is excluded from git to avoid commiting any sensible information
- `edge-deployment-manifests/`
  - `manifest-simulated-temperature.template`: Template file to be used to create the manifest-simulated-temperature.json file with the proper values
    - Note that the module was configured to send an unlimited number of messages by setting the environment variable MessageCount = -1 (see: https://github.com/Azure/iotedge/blob/027a509549a248647ed41ca7fe1dc508771c8123/edge-modules/SimulatedTemperatureSensor/src/Program.cs)
  - `manifest-simulated-temperature.json`: Generated file from the manifest-simulated-temperature.template, can be safely deleted and is excluded from git to avoid commiting any sensible information
- `reference-files\`
  - `install-iotedg.sh`: Script with the basic steps needed to install Azure IoT Edge daemon on a Lunix based device
  - `sample-config.yaml`: Sample file of the IoTEdge device configuration

## VNets configuration
VNet: IT - Informational Technology
- Address space: 10.1.0.0/16
- Subnet: Default
  - Address space: 10.1.1.0/24
  - Resources:
    - DPS: 1 Private Endpoint, 1 NIC, 1 IP Address
    - IoT Hub: 1 Private Endpoint, 1 NIC, 2 IP Addresses
    - ACR: 1 Private Endpoint, 1 NIC, 2 IP Addresses
    - [TODO]: Azure Stream Analytics cluster
- Subnet: AzureBastionSubnet
  - Address space: 10.1.0.0/27
  - Resources: Bastion

VNet: OT - Operational Technology
- Address space: 10.2.0.0/16
- Subnet: Default
  - Address space: 10.2.1.0/24
  - Resources: VM for IoT Edge simulated device

Peered networks:
- IT <-> OT

# ==> TODO <==
- Private endpoints for Storage Accounts
- With Private endpoints configured on all services, create the Private DNS for all services where a private endpoint exists and then remove the public access on the services.
  - Create Private DNS zones needed for:
    - DPS
      - Zone: `privatelink.azure-devices-provisioning.net`
        - A record: _DPS name_ : IP of private endpoint nic
    - IoT Hub
      - Zone: `privatelink.azure-devices.net`
        - A record: _IoT Hub name_ : IP of private endpoint nic
      - Zone: `privatelink.servicebus.windows.net`
        - A record: _the generated ServiceBus name of the IoT Hub_ : IP of private endpoint nic
    - ACR
      - Zone: `privatelink.azurecr.io`
        - A record: _ACR name_ : IP of private endpoint nic
        - A record: _ACR name_`.<region>.data` : IP of private endpoint nic
    - Storage Accounts
      - Zone: `privatelink.blob.core.windows.net`
        - A record: _Blob Container name_ : IP of private endpoint nic
  - Link the Private DNS with the OT VNet (check if the IT VNet is also needed)
  - For more info on Private DNS see:
    - https://docs.microsoft.com/en-us/azure/iot-hub/virtual-network-support
    - https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns
- [Optional] Azure Streaming Analytics cluster to generate some sort of alert
- [Optional] LogAnalytics and have diags configured on all servicies to use it
- [Optional] More than one VM as Edge device, eventually on a second OT VNet, to get simulation data from multiple devices