#!/bin/bash
# This script prepares an Azure Marketplace Ubuntu 22.04 Data Science Virtual Machine

# Update the package list
echo "Updating the package list"
sudo apt-get update

# Before continuing with the installation, check if dpkg is locked and wait for it to be unlocked
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    echo "Waiting 5 seconds for other software managers to finish..."
    sleep 5
done

# Remove the default XFCE screensaver to prevent screen lock
echo "Removing the default XFCE screensaver"
sudo apt-get remove xfce4-screensaver -y

# Disable Compositing in XFCE <<<<<<<<<<<<<<<--<<<<<<<<<<<<<<<-- MIGHT NOT BE NEEDED -- LEAVE FOR FUTURE REFERENCE!
# echo "Disabling Compositing in XFCE"
# xfconf-query -c xfwm4 -p /general/use_compositing -s false
# xfconf-query --create -c 'xfwm4' -p '/general/use_compositing' --type 'bool' --set 'false'

# Remove the broken Firefox installation in U22.04 DSVM
echo "Removing the broken Firefox installation"
sudo snap remove --purge firefox
sudo apt purge firefox -y
## If the above does not remove the broken Web Browser icon from the XFCE panel, try the following
# ## IMPORTANT: The plugin number may change, check the current number manually by looking at the .desktop files in ~/.config/xfce4/panel/launcher-NN (where NN is the plugin number)
# ## This command may be of help: sudo find /home/*/.config -type f -exec grep -l "microsoft-edge-dev.desktop"
echo "Removing the broken Web Browser icon from the XFCE panel"
xfconf-query --reset -c 'xfce4-panel' -p '/plugins/plugin-11' --recursive

# Before continuing with the installation, check if dpkg is locked and wait for it to be unlocked
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    echo "Waiting 5 seconds for other software managers to finish..."
    sleep 5
done

# Remove MS Edge Dev and install Prod version
echo "Removing the dev version of Microsoft Edge and installing the prod version"
## Remove the dev version
echo "Removing the dev version of Microsoft Edge"
sudo apt-get remove microsoft-edge-dev -y
## Download and install the prod version
## Latest stable version listed here: https://www.microsoft.com/en-us/edge/business/download?form=MA13FJ
## Repo visible here: https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/
msEdgeProdVersion="135.0.3179.54"
echo "Downloading and installing Microsoft Edge version $msEdgeProdVersion"
wget https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_$msEdgeProdVersion-1_amd64.deb -O microsoft-edge.deb
echo "Installing Microsoft Edge"
sudo apt install ./microsoft-edge.deb -y
# Check if there was no error and delete the downloaded file
if [ $? -eq 0 ]; then
    echo "Microsoft Edge installed successfully"
    rm microsoft-edge.deb
else
    echo "Error installing Microsoft Edge: $?"
    exit 1
fi

## To change to Base 64 encoding run:
##      cat configure_DSVM_2204.sh | base64 -w 0 > configure_DSVM_2204.sh.b64