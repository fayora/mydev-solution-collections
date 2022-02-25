[CmdletBinding()]
[OutputType([psobject])]
param (
    [string]$subscriptionId,
    [string]$resourceGroupName,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$deployedVirtualMachineName
)


process {
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
            # The VM is currently running, so stopping it
            $statusChangeResponse = Invoke-WebRequest `
            -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/deallocate?api-version=2021-03-01" `
            -Method POST `
            -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $access_token" } 

            ###NEEDS CODE TO CHECK 200 vs. DIFF RETURN! <--LOOK AT LOOME API CODE

            $result = "The app is currently stopping."

        } elseif ($vmStatus -eq "VM deallocated") {
             # The VM is currently stopped, so starting it
             $statusChangeResponse = Invoke-WebRequest `
             -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/start?api-version=2021-03-01" `
             -Method POST `
             -ContentType "application/json" `
             -Headers @{ Authorization = "Bearer $access_token" } 

             ###NEEDS CODE TO CHECK 200 vs. DIFF RETURN! <--LOOK AT LOOME API CODE

             $result = "The app is currently starting."
        } else {
            $result = "The app is currently in a transitioning state: $vmStatus. Wait a couple of minutes and try again."
        }
        New-Object -Property @{ReturnText = "$result" } -TypeName psobject
    }
    catch {
        Write-Error "Unable to determine the current status of this app. Please try again in a few minutes." $_.Exception.Message
        New-Object -Property @{ReturnText = "Unable to determine the current status of this app. Please try again in a few minutes. " + $_.Exception.Message } -TypeName psobject
    }
}

