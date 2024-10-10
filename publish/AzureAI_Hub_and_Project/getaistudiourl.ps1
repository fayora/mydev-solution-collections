[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$azureAIStudio
)
process {
    New-Object -Property @{ReturnText = "$azureAIStudio"} -TypeName psobject
}