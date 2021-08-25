[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fullyQualifiedDomainName
)
process {
    $JupyterHubURL = "https://" + $fullyQualifiedDomainName + ":8888"
    New-Object -Property @{ReturnText = "$JupyterHubURL"} -TypeName psobject
}