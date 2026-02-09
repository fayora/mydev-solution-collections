# [07:36:14 INF] Setting parameter $subscriptionId = 905e5a3e-a489-448f-8370-cda60c191ecc
# [07:36:14 INF] Setting parameter $resourceGroupName = rg-OssontClusterTest-zdvbndv-BizDataClusters
# [07:36:14 INF] Setting parameter $location = uksouth
# [07:36:14 INF] Setting parameter $virtualMachineName = whyname
# [07:36:14 INF] Setting parameter $size = 120 CPUs, 456GB of RAM
# [07:36:14 INF] Setting parameter $adminUsername = ossonts
# [07:36:14 INF] Setting parameter $adminPassword = K*R*4CEjtLS#DroUY33KjM
# [07:36:14 INF] Setting parameter $loginUsername = ossonts
# [07:36:14 INF] Setting parameter $privateIPAddress = 10.211.128.70
# [07:36:14 INF] Setting parameter $deployedVirtualMachineName = hpc-whynameu5abyk3bpuvuw
# This script stops or starts the VM based on its current status.
try {


    # TIP: Get-Command Get-AzVM | select name, module
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        Install-Module -Name Az.Compute -AllowClobber -Scope CurrentUser -Force -ErrorAction Stop
    }

    
           # take the var SKUlist, decode from base64
    $SKUlist = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($SKUlist64))

    $SKUlistjson = $SKUlist | ConvertFrom-Json
    # get the new sku
    $size = $SKUlistjson.medium.SKU
    $sizeMessage= $SKUlistjson.medium.description
        # $resourceGroupName = "rg-OssontClusterTest-zdvbndv-BizDataClusters"
        # $deployedVirtualMachineName = "hpc-whynameu5abyk3bpuvuw"
        $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $deployedVirtualMachineName
        $vmState = $vm.ProvisioningState #ProvisioningState
        if ($vmState -ne "Succeeded") {
            $result = "The VM is currently transitioning. Please try again in a few minutes."
            # return $result
        } elseif  ($vm.HardwareProfile.VmSize -ne $size) {
            $vm.HardwareProfile.VmSize = $size
            #save the changes
            Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm -Verbose
            $result =  $sizeMessage
        }elseif ($vm.HardwareProfile.VmSize -eq $size) {
            $result = "VM is already Resized to: $sizeMessage"
            # return $result
        }
   
}
catch {
    $result = "Unable to determine the status of this VM. Please try again in a few minutes. $($_.Exception.Message)"
}

