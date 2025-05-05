$fileName = "$deployedVirtualMachineName.rdp"
try {
    $RDPSettings = @()
    #FQDN for connection
    $RDPSettings += "full address:s:$privateIpAddress"
    $RDPSettings += "\n"
    #Disable desktop composition
    $RDPSettings += "allow desktop composition:i:0"
    $RDPSettings += "\n"
    #Enable Font Smoothing
    $RDPSettings += "allow font smoothing:i:1"
    $RDPSettings += "\n"
    #Enable AutoReconnect
    $RDPSettings += "autoreconnection enabled:i:1"
    $RDPSettings += "\n"
    #Enable Bitmap Caching
    $RDPSettings += "bitmapcachepersistenable:i:1"
    $RDPSettings += "\n"
    $RDPSettings += "bitmapcachesize:i:32000"
    $RDPSettings += "\n"
    #Enable Compression
    $RDPSettings += "compression:i:1"
    $RDPSettings += "\n"
    #Disable Full Window Drag
    $RDPSettings += "disable full window drag:i:1"
    $RDPSettings += "\n"
    #Disable Menu Animations
    $RDPSettings += "disable menu anims:i:1"
    $RDPSettings += "\n"
    #Disable Themes
    $RDPSettings += "disable themes:i:1"
    $RDPSettings += "\n"
    #Disable Wallpaper
    $RDPSettings += "disable wallpaper:i:0"
    $RDPSettings += "\n"
    #Keyboard Shortcut Settins Enabled in Full Screen
    $RDPSettings += "keyboardhook:i:2"
    $RDPSettings += "\n"
    #Set DX Rendering to Local Machine not HD Server
    $RDPSettings += "redirectdirectx:i:0"
    $RDPSettings += "\n"
    #Display Full Screen
    $RDPSettings += "screen mode id:i:2"
    $RDPSettings += "\n"
    #Colour Display Depth
    $RDPSettings += "session bpp:i:16"
    $RDPSettings += "\n"
    #Disable Smart Sizing
    $RDPSettings += "smart sizing:i:0"
    $RDPSettings += "\n"
    #Enable RDP Efficient Media Streaming
    $RDPSettings += "videoplaybackmode:i:1"
    $RDPSettings += "\n"
    #Disable Curson Animation
    $RDPSettings += "disable cursor setting:i:0"
    $RDPSettings += "\n"
    #Stop Auto Detect
    $RDPSettings += "networkautodetect:i:0"
    $RDPSettings += "\n"
    $RDPSettings += "bandwidthautodetect:i:0"
    $RDPSettings += "\n"
    #Enable Connection Bar
    $RDPSettings += "displayconnectionbar:i:1"
    $RDPSettings += "\n"
    #Enable WS Reconnect
    $RDPSettings += "enableworkspacereconnect:i:0"
    $RDPSettings += "\n"

    #Misc Defaults
    $RDPSettings += "gatewayhostname:s:"
    $RDPSettings += "\n"
    $RDPSettings += "gatewayusagemethod:i:4"
    $RDPSettings += "\n"
    $RDPSettings += "gatewaycredentialssource:i:4"
    $RDPSettings += "\n"
    $RDPSettings += "gatewayprofileusagemethod:i:0"
    $RDPSettings += "\n"
    $RDPSettings += "promptcredentialonce:i:0"
    $RDPSettings += "\n"
    $RDPSettings += "gatewaybrokeringtype:i:0"
    $RDPSettings += "\n"
    
    $result = "{""fileName"":""$fileName"", ""fileContent"":""$RDPSettings""}"
}
catch {
    Write-Host "Unable to generate the text file: " $_.Exception.Message
}


