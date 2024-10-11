# Make sure these two vars are at the top
$executionPolicy = 'RemoteSigned'
# $keepFile = 'True'

try {
    # Get an access token for managed identities for Azure resources
    $response = Invoke-WebRequest `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -Headers @{Metadata = "true" }
    $content = $response.Content | ConvertFrom-Json
    $access_token = $content.access_token
    Write-Host $access_token

    # Use the access token to get resource information for the VM
    $currentStatusResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/instanceView?api-version=2021-03-01" `
        -Method GET `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" }

    # Write-Host $currentStatusResponse

    $currentStatusContent = $currentStatusResponse.Content | ConvertFrom-Json

    # Write-Host $currentStatusContent

    $vmStatus = $currentStatusContent.statuses[1].displayStatus
    Write-Host $vmStatus


    if ($vmStatus -eq "VM running") {
        # The VM is currently running
        $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}"

    } elseif ($vmStatus -eq "VM deallocated") {
        # The VM is currently stopped
        $result = "{""code"":""Failed"", ""message"":""Stopped"", ""isOngoing"": false}"
    } else {
        # The VM is currently transitioning
        $result = "{""code"":""Information"", ""message"":""Transitioning"", ""isOngoing"": true}"
    }

    $result = "$result"
}
catch {
    Write-Host "Unable to get status for VM: "  $_.Exception.Message
}
