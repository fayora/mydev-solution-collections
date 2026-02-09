# This script returns the Endpoint URI for the Azure AI Foundry project

# Set for troubleshooting, so that the agent preserves the script file
# $keepFile = 'True'

# Return the Endpoint URI
try {
    $result = "$foundryPortalURL"
}
catch {
    Write-Host "Unable to get the Endpoint URI. Please check the parameters. Error returned: " $_.Exception.Message
}
