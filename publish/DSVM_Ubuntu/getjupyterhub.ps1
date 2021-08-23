[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$FQDN
)
$JupyterHubURL = "https://" + $FQDN + ":1010"
Start-Process "$JupyterHubURL"