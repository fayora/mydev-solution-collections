# This script returns the name the Azure OpenAI deployment, which is part of the parameters in the body of the API calls.

# Set for troubleshooting, so that the agent preserves the script file
$keepFile = 'True'

# Return the Endpoint URI
try {
    $result = "$deploymentName"
}
catch {
    Write-Host "Unable to get the deployment name. Please check the parameters. Error returned: " $_.Exception.Message
}
