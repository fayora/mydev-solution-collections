# This script updates a VM to use NVMe disk controller and changes the VM size.
# Make sure that the VM size you are changing to supports NVMe disks.
# Usage:
<# 
pwsh ./update_to_NVMe.ps1 `
	-vm_name "migueltestvm" `
	-vm_size_change_to "Standard_D8ads_v6" `
	-resource_group_name "rg-MiguelProject-BizDataDevandTest" `
	-subscription_id "xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#>


param (
    [Parameter(Mandatory = $true)]
    [string]$vm_name,

    [Parameter(Mandatory = $true)]
    [string]$vm_size_change_to,

    [Parameter(Mandatory = $true)]
    [string]$resource_group_name,

    [Parameter(Mandatory = $true)]
    [string]$subscription_id
)


# Default
$disk_controller_change_to="NVMe"
Write-Output "Changing disk controller to '$disk_controller_change_to'"


######################################################
# Get the VM details
######################################################
try {
    $vm = Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name -ErrorAction Stop
    Write-Output "Successfully retrieved VM '$vm_name'."
} catch {
    $errorMessage = $_.Exception.ErrorMessage
    Write-Output "ErrorMessage: $errorMessage"
    return
}


######################################################
# Stop and Deallocate the VM
######################################################
$vmStatus = Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name -Status
$powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus

if ($powerState -ne "VM deallocated") {
    Write-Output "Stopping VM..."
    Stop-AzVM -Name $vm_name -ResourceGroupName $resource_group_name -Force
} else {
    Write-Output "VM is already deallocated."
}


######################################################
# Get the OS Disk Name
######################################################
$osDisk = $vm.StorageProfile.OsDisk

if (-not $osDisk -or -not $osDisk.Name) {
    Write-Output "No OS disk found. Exiting script."
    return
} else {
    $os_disk_name = $osDisk.Name
    Write-Output "OS Disk found: '$os_disk_name'"
}


######################################################
# Set the Disk Controller Type
######################################################
$vm.StorageProfile.DiskControllerType = $disk_controller_change_to


######################################################
# Set the new VM size (with NVMe support)
######################################################
$vm.HardwareProfile.VmSize = $vm_size_change_to


######################################################
# Get full REST API endpoint
######################################################
Write-Output "Acquiring REST API endpoint"
$uri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/disks/{2}?api-version=2023-04-02' -f $subscription_id, $resource_group_name, $os_disk_name


######################################################
# Prepare json for the supported capabilities of a Disk (both SCSI and NVMe)
######################################################
$body_nvmescsi = @'
{
    "properties": {
        "supportedCapabilities": {
            "diskControllerTypes":"SCSI, NVMe"
        }
    }
}
'@



######################################################
# Get a new ARM token and prepare Authorization header
######################################################
Write-Output "Preparing Authorization header"
$token = az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv

$auth_header = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}


######################################################
# Update disk to support SCSI and NVMe controllers via REST API
######################################################
Write-Output "Updating disk"
$Update_Supported_Capabilities = (Invoke-WebRequest -uri $uri -Method PATCH -body $body_nvmescsi -Headers $auth_header)


######################################################
# Apply and save changes to the VM
######################################################
Write-Output "Saving changes to VM"
Update-AzVM -ResourceGroupName $resource_group_name -VM $vm