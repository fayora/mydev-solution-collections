[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter(Mandatory = $true)]
    [string]$privateIpAddress,
    [Parameter(Mandatory = $true)]
    [string]$loginUsername
)
process {
    $X2GoInfo = "Open your X2Go Client application and connect to your virtual machine by using the following session information:\n - Host: $privateIpAddress\n - Login: $loginUsername\n - SSH port: 22\n - Session type: XFCE\n\nIf you don't have X2Go Client already installed on your computer, you can go here: https://wiki.x2go.org/doku.php/doc:installation:x2goclient \n\n*NOTE: if you get an error when trying to connect, wait a couple of minutes and try again. The virtual machine needs time to load and configure everything when it first starts, before it becomes fully available."
    New-Object -Property @{ReturnText = "{""fileName"":""X2GoConnectionInstructions.txt"", ""fileContent"":""$X2GoInfo""}" } -TypeName psobject
}


