# This script triggers the Budget Enforcement function to run immediately by calling the Admin API of the Function App.
# Comment or uncomment the line below to keep or remove (default) script file that Loome runs.
$keepFile="True"

# Install the Az.Functions module if not already installed
if (-not (Get-Module -ListAvailable -Name Az.Functions)) {
    Install-Module -Name Az.Functions -Force -Scope CurrentUser
}

# Find the Function App in the RG
$functionApp = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId | Where-Object { $_.Name -like 'loome-budget-*' } | Select-Object -First 1

if (-not $functionApp) {
    Write-Error "No Budget Enforcement Function App found in resource group $resourceGroupName."
    exit 1
}

$appName = $functionApp.Name
$functionName = "BudgetEnforcement"

Write-Host "Found Function App: $appName"
Write-Host "Triggering function: $functionName..."

# Get the Master Key to authenticate to the Admin API
# We use Invoke-AzRestMethod to get the key from the ARM control plane
$subId = $subscriptionId
$keysUri = "/subscriptions/$subId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$appName/host/default/listkeys?api-version=2022-09-01"

try {
    $keysResponse = Invoke-AzRestMethod -Method POST -Path $keysUri
    if ($keysResponse.StatusCode -ne 200) {
        throw "Failed to retrieve Function App keys. Status: $($keysResponse.StatusCode)"
    }
    
    $keysInfo = $keysResponse.Content | ConvertFrom-Json
    $masterKey = $keysInfo.masterKey
    
    # Trigger the function via Admin API
    $triggerUri = "https://$appName.azurewebsites.net/admin/functions/$functionName"
    $headers = @{
        "x-functions-key" = $masterKey
        "Content-Type" = "application/json"
    }
    
    # We post an empty body `{}` (input is usually ignored for manual timer run, or we can pass input)
    Invoke-RestMethod -Method POST -Uri $triggerUri -Headers $headers -Body "{}" -ContentType "application/json"
    
    $result = "Function triggered successfully. Check the Function App logs for execution details."
    
} catch {
    $result = "Failed to run now. $($_.Exception.Message)"
}
