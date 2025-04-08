[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$subscriptionId,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$resourceGroupName1,
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
            -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName1/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/instanceView?api-version=2021-03-01" `
            -Method GET `
            -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $access_token" } 
        
        $currentStatusContent = $currentStatusResponse.Content | ConvertFrom-Json
        $vmStatus = $currentStatusContent.statuses[1].displayStatus
       
        if ($vmStatus -eq "VM running") {
            $result = "The VM is currently running."
        } elseif ($vmStatus -eq "VM deallocated") {
            $result = "The VM is currently stopped (deallocated)."
        } else {
            $result = "The VM is currently in a transitioning state: $vmStatus. Wait a couple of minutes before turning it on or off."
        }
        New-Object -Property @{ReturnText = "$result" } -TypeName psobject
    }
    catch {
        Write-Error "Unable to get VM status. Please try again in a few minutes." $_.Exception.Message
    }
}

