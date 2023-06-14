[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$azureOpenAIStudio
)
process {
    New-Object -Property @{ReturnText = "$azureOpenAIStudio"} -TypeName psobject
}