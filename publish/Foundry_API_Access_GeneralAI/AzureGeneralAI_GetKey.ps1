# This script gets the API key for the Azure OpenAI deployment

# Set for troubleshooting, so that the agent preserves the script file
$keepFile = 'True'

try {

    # Check if the Azure PowerShell modules are installed, if not install them
    if (-Not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Install-Module -Name Az.Accounts -Repository PSGallery -Force
    }
    if (-Not (Get-Module -ListAvailable -Name Az.CognitiveServices)) {
        Install-Module -Name Az.CognitiveServices -Repository PSGallery -Force
    }
    # Connect to azure account via managed identity
    Connect-AzAccount -Identity

    # Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # API Key
    $accountKeys = Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroupName -Name $AIAccountName
    $apiKey = $accountKeys.Key1
    if (-not $apiKey) {
        Write-Error "API Key not found. Please check the Cognitive Services account."
        exit 1
    }

    # # For troubleshooting: quickly check if the API key is valid
    # $headers = @{
    #         "api-key" = $apiKey
    #         "Content-Type" = "application/json"
    # }

    # $messages = @(
    #         @{
    #             "role" = "user"
    #             "content" = "What model version are you? Respond only with the version name, please." 
    #         }
    # )

    # $body = @{
    #         messages = $messages
    #     } | ConvertTo-Json -Depth 10

    # try {
    #     $testResponse = Invoke-RestMethod -Uri $endpointURI -Method Post -Headers $headers -Body $body
    # } catch {
    #     Write-Error "Failed to connect to the endpoint. Please check the endpoint URI. Error returned: " $_.Exception.Message
    #     exit 1
    # }

    # Return the API key
    $result = "$apiKey"
}
catch {
    Write-Host "Unable to get the API key. Please check the endpoint URI. Error returned: " $_.Exception.Message
}
