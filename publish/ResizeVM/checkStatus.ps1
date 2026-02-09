# Make sure these two vars are at the top
$executionPolicy = 'RemoteSigned'
# $keepFile = 'True'


try {
    # TIP: Get-Command Get-AzVM | select name, module
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        Install-Module -Name Az.Compute -AllowClobber -Scope CurrentUser -Force -ErrorAction Stop
    }
    
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

#  write-host $fullPriceLinux

 if($enableSpot -eq 'true') {
    $cost=  $spotPriceLinuxUnitPrice
} else {
    $cost=  $fullPriceLinuxUnitPrice
}
 

    # running
    if ($statusAz -eq "VM running") {
        $status = "Running"
        $code = "OK"
    } elseif ($statusAz -eq "VM deallocated") {
        $status = "Deallocated"
        $code = "Failed"
        $isOngoing = $false
    } elseif ($statusAz -eq "VM stopped") {
        $status = "Deallocating"
        $code = "Information"
        $isOngoing = $true
    
    } else {
        $status = "Transitioning"
        $isOngoing = $true
        $code = "Warning"
        $statusAz
    }
    
    # $status = 'Deployed' #NO STATUS

     
    $resultObject = [PSCustomObject]@{
        code = "$code"
        message =  "$status $size ($spotTxt$cost/hr)"
        isOngoing = $false
    }
    
    # Convert resultObject to a string


    $result = $resultObject | ConvertTo-Json -Compress
$result
    # convert to string $result and escape double quotes
    # $result = $result -replace '"', '""'
    
    # $result = [string]::Format('"{0}"', $result)
    # remove newline
    # $result = $result -replace '\r?\n', ''
    # FROM DOCS
    # $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}";  

    # $result = "$result"
}
catch {
    Write-Host "Unknown"  $_.Exception.Message
    # $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}"
    $resultObject = [PSCustomObject]@{
        code = "Failed"
        message =  "$size"
        isOngoing = $true
    }
    # Convert resultObject to a string
    $result = $resultObject | ConvertTo-Json -Compress
     

}
