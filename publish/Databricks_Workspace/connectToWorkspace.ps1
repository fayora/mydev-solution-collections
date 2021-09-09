[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspace
)
process {
    $workspaceURL = "foobar" #$workspace.workspaceUrl
    New-Object -Property @{ReturnText = "$workspaceURL"} -TypeName psobject
}