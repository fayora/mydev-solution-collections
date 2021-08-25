[CmdletBinding()]
[OutputType([psobject])]
param (
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$fullyQualifiedDomainName,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true)]
    [string]$loginUsername
)
process {

    $RDPSettings = @()
    #FQDN for connection
    $RDPSettings += "full address:s:$fullyQualifiedDomainName"
    #Disable desktop composition
    $RDPSettings += "allow desktop composition:i:0"
    #Enable Font Smoothing
    $RDPSettings += "allow font smoothing:i:1"
    #Enable AutoReconnect
    $RDPSettings += "autoreconnection enabled:i:1"
    #Enable Bitmap Caching
    $RDPSettings += "bitmapcachepersistenable:i:1"
    $RDPSettings += "bitmapcachesize:i:32000"
    #Enable Compression
    $RDPSettings += "compression:i:1"
    #Disable Full Window Drag
    $RDPSettings += "disable full window drag:i:1"
    #Disable Menu Animations
    $RDPSettings += "disable menu anims:i:1"
    #Disable Themes
    $RDPSettings += "disable themes:i:1"
    #Disable Wallpaper
    $RDPSettings += "disable wallpaper:i:0"
    #Keyboard Shortcut Settins Enabled in Full Screen
    $RDPSettings += "keyboardhook:i:2"
    #Set DX Rendering to Local Machine not HD Server
    $RDPSettings += "redirectdirectx:i:0"
    #Display Full Screen
    $RDPSettings += "screen mode id:i:2"
    #Colour Display Depth
    $RDPSettings += "session bpp:i:16"
    #Disable Smart Sizing
    $RDPSettings += "smart sizing:i:0"
    #Enable RDP Efficient Media Streaming
    $RDPSettings += "videoplaybackmode:i:1"
    #Disable Curson Animation
    $RDPSettings += "disable cursor setting:i:0"
    #Stop Auto Detect
    $RDPSettings += "networkautodetect:i:0"
    $RDPSettings += "bandwidthautodetect:i:0"
    #Enable Connection Bar
    $RDPSettings += "displayconnectionbar:i:1"
    #Enable WS Reconnect
    $RDPSettings += "enableworkspacereconnect:i:0"

    #Misc Defaults
    $RDPSettings += "gatewayhostname:s:"
    $RDPSettings += "gatewayusagemethod:i:4"
    $RDPSettings += "gatewaycredentialssource:i:4"
    $RDPSettings += "gatewayprofileusagemethod:i:0"
    $RDPSettings += "promptcredentialonce:i:0"
    $RDPSettings += "gatewaybrokeringtype:i:0"
    
    New-Object -Property @{ReturnText = "{""fileName"":""RemoteConnection.rdp"", ""fileContent"":""$RDPSettings""}" } -TypeName psobject
}


