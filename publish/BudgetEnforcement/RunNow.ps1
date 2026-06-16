# This script triggers the Budget Enforcement function to run immediately by calling the Admin API of the Function App.
# Comment or uncomment the line below to keep or remove (default) script file that Loome runs.
$keepFile="True"

# The fixed name used for the function within the Function App
$functionName = "BudgetEnforcement"

try {
    # ********** There is a bug in Az.Functions module versions 4.3.0 or newer that causes Get-AzFunctionAppSetting to fail!!
    # ********** Using REST API calls instead.

    # Set the context for Azure authentication
    ## Connect to azure account via managed identity
    Write-Host "Connecting to Azure using Managed Identity..." -ForegroundColor Cyan
    Connect-AzAccount -Identity -Subscription $subscriptionId
    Write-Host "Successfully connected to Azure." -ForegroundColor Green

    # Acquire an access token for Azure Resource Management
    Write-Host "Searching for Function App $functionAppName in resource group $resourceGroupName..." -ForegroundColor Cyan
    Write-Host "Acquiring access token for Azure Resource Management..." -ForegroundColor Cyan
    $secureToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
    $token = [System.Net.NetworkCredential]::new("", $secureToken).Password
    Write-Host "Access token acquired successfully: $token " -ForegroundColor Green
    
    # Check if the Function App exists by calling the ARM REST API directly
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }
    $baseUrl  = "https://management.azure.com"
    $apiVer   = "2023-12-01"
    $siteUrl  = "$baseUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" + "/providers/Microsoft.Web/sites/$functionAppName"
    try {
        Write-Host "`nChecking Function App: '$functionAppName' ..." -ForegroundColor Cyan
        $app = Invoke-RestMethod -Uri "$siteUrl`?api-version=$apiVer" -Headers $headers -Method GET -ErrorAction Stop
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Host "  ✗ Function App '$functionAppName' does NOT exist." -ForegroundColor Red
            $result = "{""code"":""Failed"", ""message"":""No Budget Enforcement solution found in resource group $resourceGroupName."", ""isOngoing"": false}"
            exit 1
        }
        Write-Error "No Budget Enforcement solution found in resource group $resourceGroupName." -ForegroundColor Red
        $result = "{""code"":""Failed"", ""message"":""No Budget Enforcement solution found in resource group $resourceGroupName."", ""isOngoing"": false}"
        exit 1
    }

    Write-Host "Found Function App: $functionAppName" -ForegroundColor Green
    
    Write-Host "Triggering function: $functionName..."

    # Get the Master Key to authenticate to the Admin API
    # We use Invoke-AzRestMethod to get the key from the ARM control plane
    $keysUri = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$functionAppName/host/default/listkeys?api-version=2022-09-01"

    try {
        $keysResponse = Invoke-AzRestMethod -Method POST -Path $keysUri
        if ($keysResponse.StatusCode -ne 200) {
            throw "Failed to retrieve Function App keys. Status: $($keysResponse.StatusCode)"
        }
        
        $keysInfo = $keysResponse.Content | ConvertFrom-Json
        $masterKey = $keysInfo.masterKey
        
        # Trigger the function via Admin API
        $triggerUri = "https://$functionAppName.azurewebsites.net/admin/functions/$functionName"
        $headers = @{
            "x-functions-key" = $masterKey
            "Content-Type" = "application/json"
        }
        
        # We post an empty body `{}` (input is usually ignored for manual timer run, or we can pass input)
        Invoke-RestMethod -Method POST -Uri $triggerUri -Headers $headers -Body "{}" -ContentType "application/json"
        Write-Host "Function triggered successfully. Check the Function App logs for execution details." -ForegroundColor Green
        $result = "Function triggered successfully. Check the Function App logs for execution details."
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $result = "Failed to run now. Try again in a few moments. $($_.Exception.Message)"
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $result = "Failed to run now. Try again in a few moments. $($_.Exception.Message)"
}