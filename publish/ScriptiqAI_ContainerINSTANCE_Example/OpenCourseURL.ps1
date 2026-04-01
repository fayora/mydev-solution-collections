# This script returns the Endpoint URI for the Azure OpenAI deployment
$executionPolicy = 'RemoteSigned'
# Set for troubleshooting, so that the agent preserves the script file
# $keepFile = 'True'

# Return the Endpoint URI
try {
    $result = "$courseEnrolmentURLLink"
}
catch {
    Write-Host "Unable to get the course URL. Please try again later. Error returned: " $_.Exception.Message
}
