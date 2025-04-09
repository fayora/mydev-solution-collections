[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$privateIpAddress
)
process {
    $JupyterHubURL = "https://" + $privateIpAddress + ":8000"
    New-Object -Property @{ReturnText = "$JupyterHubURL"} -TypeName psobject
}