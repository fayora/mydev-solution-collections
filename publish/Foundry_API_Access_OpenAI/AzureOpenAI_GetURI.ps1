# This script returns the Endpoint URI for the Azure OpenAI deployment

# Set for troubleshooting, so that the agent preserves the script file
$keepFile = 'True'

# Endpoint URI
# $APIVersion = "2025-01-01-preview"
# $endpointURI = "https://" + $AIAccountName + ".api.cognitive.microsoft.com/openai/deployments/" + $deploymentName + "/chat/completions?api-version=" + $APIVersion

# Return the Endpoint URI
try {
    $result = "$endpointURI"
}
catch {
    Write-Host "Unable to get the Endpoint URI. Please check the parameters. Error returned: " $_.Exception.Message
}
