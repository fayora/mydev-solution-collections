#!/bin/bash
# From: https://github.com/Azure/Azure-Managed-Lustre/blob/main/docs/_includes/client-install-ubuntu18.md

# The IP address of the Lustre server (update with each deployment!!)
amlfsIPaddress="10.0.4.4"

# Install the Lustre client
apt update && apt install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
echo "deb [arch=amd64] https://packages.microsoft.com/repos/amlfs/ bionic main" | tee /etc/apt/sources.list.d/amlfs.list
apt update && apt search lustre
apt install -y lustre-client-modules-$(uname -r)

# Mount the lustre filesystem
mkdir -p /lustre
mount -t lustre -o noatime,flock $($amlfsIPaddress)@tcp:/lustrefs /lustre
chmod -R 777 /lustre