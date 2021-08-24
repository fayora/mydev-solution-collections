[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fullyQualifiedDomainName,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$LoginUsername
)
process {
    $X2GoInfo = "Open your X2Go Client application and connect to your virtual machine by using the following session information:`r`n- Host: $fullyQualifiedDomainName`r`n- Login: $LoginUsername`r`n-SSH port: 22`r`n- Session type: XFCE.`r`n`r`nIf you don't have X2Go Client already installed on your computer, you can go here: https://wiki.x2go.org/doku.php/doc:installation:x2goclient"
    New-Object -Property @{ReturnText = "{""fileName"":""X2GoConnectionInstructions.txt"", ""fileContent"":""$X2GoInfo""}" } -TypeName psobject
}


