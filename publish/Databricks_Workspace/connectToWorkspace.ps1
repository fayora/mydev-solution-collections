[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspace
)
process {
    $workspaceURL = $workspace
    New-Object -Property @{ReturnText = "$workspaceURL"} -TypeName psobject
}