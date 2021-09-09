[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspaceURL,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$workspaceURL2
)
process {
    $workspaceURL3 = "URL1: " + $workspaceURL + " ; URL2: " + $workspaceURL2
    New-Object -Property @{ReturnText = "$workspaceURL3"} -TypeName psobject
}