[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$subscriptionId,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$resourceGroupName1,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$publicIpAddressName,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$adminUsername
)
process {
    try {

        # Get an access token for managed identities for Azure resources
        $response = Invoke-WebRequest `
            -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
            -Headers @{Metadata = "true" }
        $content = $response.Content | ConvertFrom-Json
        $access_token = $content.access_token

        
        # Use the access token to get the RDP connection for the VM
        $publicIpAddressResponse = Invoke-WebRequest `
            -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName1/providers/Microsoft.Network/publicIPAddresses/$publicIpAddressName\?api-version=2020-11-01" `
            https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.DevTestLab/labs/{labName}/virtualmachines/{name}/getRdpFileContents?api-version=2018-09-15 
            -Method GET `
            -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $access_token" } 
        
        $publicIpAddressContent = $publicIpAddressResponse.Content | ConvertFrom-Json
       
        if (!$publicIpAddressContent.properties.ipAddress) { throw "IP address does not exist." }
       
        $ipAddress = $publicIpAddressContent.properties.ipAddress
       
        
        New-Object -Property @{ReturnText = "mstsc /v$ipAddress" } -TypeName psobject
    }
    catch {
        Write-Host "Unable to get IP address." $_.Exception.Message
    }
}

