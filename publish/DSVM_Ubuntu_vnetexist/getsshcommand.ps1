[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter(Mandatory = $true)]
    [string]$privateIpAddress,
    [Parameter(Mandatory = $true)]
    [string]$loginUsername
)

process {
    try {
        if (!$privateIpAddress) {
            throw "Private IP address not found on NIC."
        }

        # Output SSH command
        New-Object -TypeName psobject -Property @{
            ReturnText = "ssh $loginUsername@$privateIpAddress"
        }
    }
    catch {
        Write-Host "Unable to retrieve private IP address:" $_.Exception.Message
    }
}
