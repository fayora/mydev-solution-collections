[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fullyQualifiedDomainName
)
process {
    $RStudioServerURL = "https://" + $fullyQualifiedDomainName + ":8787"
    New-Object -Property @{ReturnText = "$RStudioServerURL"} -TypeName psobject
}