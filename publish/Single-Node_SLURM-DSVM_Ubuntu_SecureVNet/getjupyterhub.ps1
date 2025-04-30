# Make sure these two vars are at the top

$executionPolicy = 'RemoteSigned'

# $keepFile = 'True'

try {

    # Use String from the output of the ARM script
    $JupyterHubURL = "https://" + $privateIpAddress + ":8000"
    $result = "$JupyterHubURL"

}
catch {

    Write-Host "Unable to get URL." $_.Exception.Message

}