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
# $keepFile = true
try {
    # TIP: Get-Command Get-AzVM | select name, module
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        Install-Module -Name Az.Compute -AllowClobber -Scope CurrentUser -Force -ErrorAction Stop
    }

        # take the var SKUlist, decode from base64
    $SKUlist = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($SKUlist64))

    $SKUlistjson = $SKUlist | ConvertFrom-Json

    
    # authenticate 
    Connect-AzAccount -Identity
    Set-AzContext -Subscription $subscriptionId

    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $deployedVirtualMachineName
    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $deployedVirtualMachineName -status
    $size = $vm.HardwareProfile.VmSize
    $size =   $size -replace  'Standard_' , ''
    $cost = "9.99/hr" 
    $statusAz = $vmStatus.Statuses[1].DisplayStatus
    #if statusAz contains VM running then set status running
             

    $code = "Warning"
    $isOngoing = $true

    $isSpot = $vm.Priority -eq "Spot"
    $spotTxt = if ($isSpot) { "Spot" } else { "" }

    #price 
    # Define the parameters for the API call
    $region = $location
    $vmSeries = $vm.HardwareProfile.VmSize  # <--- CHECK THIS SKU


    # Define the API URL
 # Construct the filter for the API query
 # Only Vm
 $filter = "serviceName eq 'Virtual Machines' "
 # Only in my region
 $filter += "and armRegionName eq '$region' "
 # Only for the SKU being used
 $filter += "and armSkuName eq '$vmSeries' "
 # consumption only prices
 $filter += "and type eq 'Consumption'"

 # All info is here: https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview

 $urlfilter = "$apiUrl?`$filter=$filter"
 # $urlfilter = "$urlfilter&currencyCode='GBP'" # <--- CHECK THIS CURRENCY; USD is accurate ; others are approximations
 $urlfilter = "$urlfilter&currencyCode='GBP'" # <--- CHECK THIS CURRENCY; USD is accurate ; others are approximations
 write-host "FILTER: $urlfilter"
 # Make the API call
 $response = Invoke-RestMethod -Uri "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview&$urlfilter" -Method Get

 # write-host $response
 # Extract the  price from the response
 $price = $response.Items | Where-Object { $_.unitPrice -ne $null } #| Select-Object -ExpandProperty armSkuName unitPrice meterName

 # select only those with spot in the skuname -- if you are using SPOT
 $spotPrice = $price | Where-Object { $_.skuname -like "*spot*" }
 $fullPrice = $price | Where-Object { $_.skuname -notlike "*Spot*" }

 # select those that do NOT have windows in the product name
 $spotPriceLinux = $spotPrice | Where-Object { $_.productName -notlike "*Windows*" } | Where-Object { $_.meterName -notlike "*Low Priority*" } | Where-Object { $_.productName -like "*Virtual Machines*" }
 $fullPriceLinux = $fullPrice | Where-Object { $_.productName -notlike "*Windows*" } | Where-Object { $_.meterName -notlike "*Low Priority*" }  | Where-Object { $_.productName -like "*Virtual Machines*" }

 $spotPriceWindows = $spotPrice | Where-Object { $_.productName -like "*Windows*" } | Where-Object { $_.meterName -notlike "*Low Priority*" } | Where-Object { $_.productName -like "*Virtual Machines*" }
 $fullPriceWindows = $fullPrice | Where-Object { $_.productName -like "*Windows*" } | Where-Object { $_.meterName -notlike "*Low Priority*" } | Where-Object { $_.productName -like "*Virtual Machines*" }
 # show properties of interest

 Write-host "SPOT WINDOWS"
 $spotPriceWindows #| Select-Object -Property effectiveStartDate, armSkuName,unitOfMeasure , currencyCode ,unitPrice, meterName
 Write-Host "SPOT LINUX"
 $spotPriceLinux #| Select-Object -Property effectiveStartDate, armSkuName,unitOfMeasure , currencyCode ,unitPrice, meterName

Write-Host "FULL PRICE WINDOWS"
 $fullPriceWindows #| Select-Object -Property effectiveStartDate, armSkuName,unitOfMeasure , currencyCode ,unitPrice, meterName
Write-Host "FULL PRICE LINUX" 
 $fullPriceLinux #| Select-Object -Property effectiveStartDate, armSkuName,unitOfMeasure , currencyCode ,unitPrice, meterName
# Debug output
Write-Host "SELECTED PRICE"
Write-Host "Spot Price Linux: $($spotPriceLinux.unitPrice)"
Write-Host "Spot Price Windows: $($spotPriceWindows.unitPrice)"
Write-Host "Full Price Linux: $($fullPriceLinux.unitPrice)"
Write-Host "Full Price Windows: $($fullPriceWindows.unitPrice)"


#convert  $spotPriceWindows.unitPrice to number and round to 2 decimal places
$spotPriceLinuxUnitPrice = "{0:N2}" -f $spotPriceLinux.unitPrice
$spotPriceWindowsUnitPrice =  "{0:N2}" -f  $spotPriceWindows.unitPrice 
$fullPriceLinuxUnitPrice =  "{0:N2}" -f  $fullPriceLinux.unitPrice 
$fullPriceWindowsUnitPrice =  "{0:N2}" -f  $fullPriceWindows.unitPrice 

            # return a table with the VM series and the spot prices as a markdown string
            $result = "### VM $size`n"
            
            $result += "`n | |Full| Spot|"
            $result += "`n |---|:---|:---|"
            $result += "`n |Windows | £$fullPriceWindowsUnitPrice/hour | £$spotPriceWindowsUnitPrice/hour|"
            $result += "`n |Linux | £$fullPriceLinuxUnitPrice/hour | £$spotPriceLinuxUnitPrice/hour |"
        
            $result += "`n### Resize Options`n"

            $smallSku =  $SKUlistjson.small.SKU -replace  'Standard_' , ''
            $mediumSku =  $SKUlistjson.medium.SKU -replace  'Standard_' , ''
            $largeSku =  $SKUlistjson.large.SKU -replace  'Standard_' , ''
            # other options SKUlistjson.small.SKU
            $result += "`n| Size | SKU |Spec | Description |"
            $result += "`n|:---|:---|:---|:---|"
            $result += "`n| S | $($smallSku) |  $($SKUlistjson.small.name) |  $($SKUlistjson.small.description) |"
            $result += "`n| M | $($mediumSku) |  $($SKUlistjson.medium.name) | $($SKUlistjson.medium.description) |"
        	$result += "`n| L | $($largeSku) |  $($SKUlistjson.large.name) | $($SKUlistjson.large.description) |"



            # $result = $vmSeries  + " Win(" + $spotPriceWindowsUnitPrice + ") Linux(" + $spotPriceLinuxUnitPrice + ") GBP/hour"
            # $result = "##Heading HELLO"
            
        

        # #check
        # $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $deployedVirtualMachineName
        # $vmState = $vm.ProvisioningState #ProvisioningState

        # $result = "{""code"":""Failed"", ""message"":""VM Resized."", ""isOngoing"": false}"
        # return $result

   
}
catch {
    $result = "Unable to determine the status of this VM. Please try again in a few minutes. $($_.Exception.Message)"
}

