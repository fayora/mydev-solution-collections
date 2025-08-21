# This script returns the Endpoint URI for the Azure OpenAI deployment

# Set for troubleshooting, so that the agent preserves the script file
# $keepFile = 'True'

# Return the Endpoint URI
try {
    $result = "$OllamaContainerURI"
}
catch {
    Write-Host "Unable to get the Endpoint URI. Please check the parameters. Error returned: " $_.Exception.Message
}
