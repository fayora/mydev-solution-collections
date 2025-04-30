#!/bin/bash
# This script prepares an Azure Marketplace Ubuntu 22.04 Data Science Virtual Machine

# A function to create a comment with a timestamp
function logMessage {
    commentTimeStamp="[`date +%Y-%m-%d_%H:%M:%S.%2N`]~"
    echo "$commentTimeStamp $1" | tee -a /tmp/configure_SLURM_DSVM_2204.log
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~ Starting the timer so that we can calculate the time it takes to run the script ~~~
SECONDS=0
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Update the package list
logMessage "Updating the package list"
sudo apt-get update

## FOR TROUBLESHOOTING: List running processes with paths
# ps auxf
# Before continuing with the installation, check if dpkg is locked and wait for it to be unlocked
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    logMessage "Waiting 5 seconds for other software managers to finish..."
    sleep 5
done


################# NVMe Disk Mounting #########################################
# Provide the path where the NVMe disk should be mounted
MOUNT_PATH="/nvmedrive"

# Check if the VM has an NVMe disk
if [ -b /dev/nvme0n1 ]; then
    logMessage "NVMe disk found. Checking if it is already mounted..."
    ## Check if the NVMe disk is already mounted
    if findmnt /dev/nvme0n1; then
        logMessage "NVMe disk is already mounted"
    else 
        logMessage "NVMe disk is not mounted"
        ## Format the partition
        sudo mkfs.ext4 /dev/nvme0n1
        ## Run partprobe to update the kernel partition table with the new drive
        sudo partprobe /dev/nvme0n1
        ## Create a mount point
        sudo mkdir -p $MOUNT_PATH
        ## Mount the partition
        sudo mount /dev/nvme0n1 $MOUNT_PATH
        ## Add the mount point to the fstab file so that it is mounted automatically after a reboot
        echo "/dev/nvme0n1 $MOUNT_PATH ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
        ## Make the mount point accessible to all users
        sudo chmod -R 777 $MOUNT_PATH
    fi
else
    logMessage "NVMe disk not found. Skipping..."
fi
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################# SLURM Installation ##########################################
# Install only if SLURM is not already installed
if [ -d "/etc/slurm" ]; then
    logMessage "SLURM is already installed! Skipping."
else
    logMessage "Installing SLURM on the local computer..."

    ## The Ubuntu 20.04 LTS HPC image does not come with the SLURM repos available, so adding them first
    logMessage "Adding the SLURM repository to the list of installers..."
    sudo add-apt-repository -y ppa:omnivector/slurm-wlm

    ## Update the installer list
    logMessage "Updating the list of installers..."
    sudo apt update

    ## Check if 'slurm' is found in the apt-cache or list of installers
    logMessage "Checking if SLURM is available in the list of installers..."
    apt-cache search slurm

    ## Install SLURM
    logMessage "Installing SLURM..."
    sudo apt install slurmd slurmctld -y
fi
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################# SLURM Configuration #########################################
logMessage "Configuring SLURM..."
# Check if the SLURM configuration file already exists
if [ -f "/etc/slurm/slurm.conf" ]; then
    logMessage "SLURM configuration file already exists. Exiting."
    exit 0
fi

logMessage "Creating the SLURM configuration file..."

## Get the number of CPUs and subtract 2 so that we do not starve the OS
numCPUs=$(nproc)
jobsCPUs=$(($numCPUs-2))

## Get the amount of RAM and subtract 10 GB so that we do not starve the OS
## IMPORTANT: Pass the amount of RAM in **MB** which is what SLURM expects
totalMem=$(LANG=C free|awk '/^Mem:/{print $2}')
jobsMem=$(($totalMem/1024-10240))

## Make the SLURM configuration directory writeable
sudo chmod 777 /etc/slurm

## Generate the SLURM configuration file
sudo cat << EOF > /etc/slurm/slurm.conf
ClusterName=localcluster
SlurmctldHost=localhost
MpiDefault=none
ProctrackType=proctrack/linuxproc
ReturnToService=2
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/lib/slurm/slurmd
SlurmUser=slurm
StateSaveLocation=/var/lib/slurm/slurmctld
SwitchType=switch/none
TaskPlugin=task/none
#
# TIMERS
InactiveLimit=0
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0
# SCHEDULING
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core
#
#AccountingStoragePort=
AccountingStorageType=accounting_storage/none
JobCompType=jobcomp/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log
#
# COMPUTE NODES
NodeName=localhost CPUs=$jobsCPUs RealMemory=$jobsMem State=UNKNOWN
PartitionName=LocalQ Nodes=ALL Default=YES MaxTime=INFINITE State=UP
EOF

## Make the SLURM configuration directory read-only
sudo chmod 755 /etc/slurm/

## Start the SLURM daemons
sudo systemctl start slurmctld
sudo systemctl start slurmd

## Start the daemons at boot
sudo systemctl enable slurmctld
sudo systemctl enable slurmd

logMessage "The SLURM daemons have been started and will start automatically at boot."

# Ensure that the local node is ready to run jobs 
#sudo scontrol update nodename=localhost state=idle
logMessage "SLURM has been installed and configured on the local computer."
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################# XFCE sand GUI tools Configuration #########################################
# Remove the default XFCE screensaver to prevent screen lock
logMessage "Removing the default XFCE screensaver"
sudo apt-get remove xfce4-screensaver -y

# Disable Compositing in XFCE <<<<<<<<<<<<<<<--<<<<<<<<<<<<<<<-- MIGHT NOT BE NEEDED -- LEAVE FOR FUTURE REFERENCE!
# logMessage "Disabling Compositing in XFCE"
# xfconf-query -c xfwm4 -p /general/use_compositing -s false
# xfconf-query --create -c 'xfwm4' -p '/general/use_compositing' --type 'bool' --set 'false'

# Remove the broken Firefox installation in U22.04 DSVM
logMessage "Removing the broken Firefox installation"
sudo snap remove --purge firefox
sudo apt purge firefox -y
## If the above does not remove the broken Web Browser icon from the XFCE panel, try the following
# ## IMPORTANT: The plugin number may change, check the current number manually by looking at the .desktop files in ~/.config/xfce4/panel/launcher-NN (where NN is the plugin number)
# ## This command may be of help: sudo find /home/*/.config -type f -exec grep -l "microsoft-edge-dev.desktop"
logMessage "Removing the broken Web Browser icon from the XFCE panel"
xfconf-query --reset -c 'xfce4-panel' -p '/plugins/plugin-11' --recursive

# Before continuing with the installation, check if dpkg is locked and wait for it to be unlocked
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    logMessage "Waiting 5 seconds for other software managers to finish..."
    sleep 5
done

# Remove MS Edge Dev and install Prod version
logMessage "Removing the dev version of Microsoft Edge and installing the prod version"
## Remove the dev version
logMessage "Removing the dev version of Microsoft Edge"
sudo apt-get remove microsoft-edge-dev -y
## Download and install the prod version
## Latest stable version listed here: https://www.microsoft.com/en-us/edge/business/download?form=MA13FJ
## Repo visible here: https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/
msEdgeProdVersion="135.0.3179.54"
logMessage "Downloading and installing Microsoft Edge version $msEdgeProdVersion"
wget https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_$msEdgeProdVersion-1_amd64.deb -O microsoft-edge.deb
logMessage "Installing Microsoft Edge"
sudo apt install ./microsoft-edge.deb -y
# Check if there was no error and delete the downloaded file
if [ $? -eq 0 ]; then
    logMessage "Microsoft Edge installed successfully"
    rm microsoft-edge.deb
else
    logMessage "Error installing Microsoft Edge: $?"
    exit 1
fi
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logMessage "Installation and configuration completed successfully."
# ~~~ Ending the timer and calculating the time it took to run the script ~~~
logMessage "The script took $((SECONDS / 60)) minutes and $((SECONDS % 60)) seconds to run."

## To change to Base 64 encoding run:
##      cat <SCRIPT-NAME>.sh | base64 -w 0 > <SCRIPT-NAME>.sh.b64

#!/bin/bash
# This script prepares an HB120 HPC VM for running single-node SLURM
# It also checks if the NVMe disk is mounted and if not, it mounts it and makes it accessible to all users.
