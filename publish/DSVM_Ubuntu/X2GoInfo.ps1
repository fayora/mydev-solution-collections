[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fullyQualifiedDomainName
)
process {
    $X2GoInfo = "Open the X2Go Client and connect over port 22, using XFCE as session type, to: $fullyQualifiedDomainName"
    New-Object -Property @{ReturnText = "$X2GoInfo"} -TypeName psobject
}