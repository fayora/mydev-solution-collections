param (
    [Parameter(Mandatory=$true)][string]$ApiKey,
    [Parameter(Mandatory=$true)][string]$EndpointUri,
    [string]$Prompt = "Hello, how are you?"
)

# Validate parameters and if not all present show usage
if (-not $ApiKey -or -not $EndpointUri) {
    Write-Host "Usage: .\TestFoundryAPI.ps1 -ApiKey <API_KEY> -EndpointUri <ENDPOINT_URI> -Model <MODEL> [-Prompt <PROMPT>]"
    exit 1
}

$headers = @{
    "api-key" = $ApiKey
    "Content-Type" = "application/json"
}

$body = @{
    "messages" = @(
        @{
            "role" = "system"
            "content" = "You are a helpful assistant that provides concise and accurate answers."
        },
        @{
            "role" = "user"
            "content" = $Prompt
        }
    )
    # "max_tokens" = 800
    # "temperature" = 0.7
    # "frequency_penalty" = 0
    # "presence_penalty" = 0
    # "top_p" = 0.95
    # "stop" = $null
} | ConvertTo-Json

$uri = $EndpointUri

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    $response.choices[0].message.content
}
catch {
    Write-Error "Error calling Azure AI API: $($_.Exception.Message)"
    exit 1
}
