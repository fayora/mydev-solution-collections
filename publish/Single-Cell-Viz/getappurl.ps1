[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fqdn
)
process {
    $appURL = "http://" + $fqdn
    New-Object -Property @{ReturnText = "$appURL"} -TypeName psobject
}