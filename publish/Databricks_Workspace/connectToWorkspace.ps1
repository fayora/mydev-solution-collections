[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspace
)
process {
    $workspaceURL = $workspace.Url
    New-Object -Property @{ReturnText = "$workspaceURL"} -TypeName psobject
}