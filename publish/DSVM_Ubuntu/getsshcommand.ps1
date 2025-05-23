# This script returns the SSH command to connect to the VM
try {
    # Get an access token for managed identities for Azure resources
    $response = Invoke-WebRequest `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -Headers @{Metadata = "true" }
    $content = $response.Content | ConvertFrom-Json
    $access_token = $content.access_token

    
    # Use the access token to get resource information for the VM
    $publicIpAddressResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/publicIPAddresses/$publicIpAddressName\?api-version=2020-11-01" `
        -Method GET `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" } 
    
    $publicIpAddressContent = $publicIpAddressResponse.Content | ConvertFrom-Json
    
    if (!$publicIpAddressContent.properties.ipAddress) { throw "IP address does not exist." }
    
    $ipAddress = $publicIpAddressContent.properties.ipAddress
    
    
    $result =  "ssh $loginUsername@$ipAddress"
}
catch {
    Write-Host "Unable to retrieve the SSH command." $_.Exception.Message
}