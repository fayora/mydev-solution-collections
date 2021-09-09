[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspaceURL
)
process {
    $workspaceURLComplete = "https://" + $workspaceURL
    New-Object -Property @{ReturnText = "$workspaceURLComplete"} -TypeName psobject
}