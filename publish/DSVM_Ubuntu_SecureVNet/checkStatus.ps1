# This script provides the status of the VM. The status can be one of the following:
# *** Return Object ***
#	code: string
#		Possible values are:
#			OK 			- Green Icon
#			Information - Blue Icon
#			Warning 	- Yellow Icon
#			Failed 		- Red Icon
#
#	message: string
#		Return messsage that is displayed on the UI and has same color as code property.
#
#	isOngoing: boolean (Optional)
#		An icon is added with style to indicate that this status is ongoing.
try {

    # Get an access token for managed identities for Azure resources
    $response = Invoke-WebRequest `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -Headers @{Metadata = "true" }
    $content = $response.Content | ConvertFrom-Json
    $access_token = $content.access_token

    
    # Use the access token to get resource information for the VM
    $currentStatusResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/instanceView?api-version=2021-03-01" `
        -Method GET `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" } 
    
    $currentStatusContent = $currentStatusResponse.Content | ConvertFrom-Json
    $vmStatus = $currentStatusContent.statuses[1].displayStatus
    
    if ($vmStatus -eq "VM running") {
        # The VM is currently running
        $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}" 

    } elseif ($vmStatus -eq "VM deallocated") {
            # The VM is currently stopped
            $result = "{""code"":""Failed"", ""message"":""Stopped"", ""isOngoing"": false}" 

    
    } elseif ($vmStatus -eq "VM stopped") {
        # The VM was incorrectly shut down by the user from the operating system, so stopping it and showing a message
        $statusChangeResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/deallocate?api-version=2021-03-01" `
        -Method POST `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" }
        $result = "{""code"":""Information"", ""message"":""Deallocating"", ""isOngoing"": false}"

    } else {
        # The VM is currently transitioning
        $result = "{""code"":""Information"", ""message"":""Transitioning"", ""isOngoing"": true}" 
    }

    New-Object -Property @{ReturnText = "$result" } -TypeName psobject
}
catch {
    Write-Error "Unable to determine the status of this VM. Please try again in a few minutes." $_.Exception.Message
}