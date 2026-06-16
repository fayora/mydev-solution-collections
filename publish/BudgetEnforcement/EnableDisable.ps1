# This script toggles the enabled/disabled state of the Budget Enforcement function in the specified resource group.

# Comment or uncomment the line below to keep or remove (default) script file that Loome runs.
$keepFile="True"

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

    # Analyze the current state of the function (Running/Stopped)
    Write-Host "Checking the status of function: BudgetEnforcement..." -ForegroundColor Cyan
    $appState   = $app.properties.state            # "Running" | "Stopped"

    if ($appState -eq "Running") {
        # The function is currently Running -- Stopping it
        Write-Host "The function $functionName is currently $appState, stopping it..." -ForegroundColor Green
        try {
            $stopResponse = Invoke-RestMethod -Uri "$siteUrl/stop?api-version=$apiVer" -Headers $headers -Method POST -ErrorAction Stop
            Write-Host "Stop command sent successfully. The function is now stopping." -ForegroundColor Green
            $result = "The solution has been stopped."
        }
        catch {
            Write-Host "Failed to stop the function: $($_.Exception.Message)" -ForegroundColor Red
            $result = "Failed to stop the solution. $($_.Exception.Message)"
        }
    }
    elseif ($appState -eq "Stopped") {
        # The function is currently Stopped -- Starting it
        Write-Host "The function $functionName is currently $appState, starting it..." -ForegroundColor Yellow
        try {
            $startResponse = Invoke-RestMethod -Uri "$siteUrl/start?api-version=$apiVer" -Headers $headers -Method POST -ErrorAction Stop
            Write-Host "Start command sent successfully. The function is now starting." -ForegroundColor Green
            $result = "The solution has been started."
        }
        catch {
            Write-Host "Failed to start the function: $($_.Exception.Message)" -ForegroundColor Red
            $result = "Failed to start the solution. $($_.Exception.Message)"
        }
    }
    else {
         # The function is in an unexpected state -- Do nothing
        Write-Host "The function $functionName is in an unexpected state: state=$appState" -ForegroundColor Yellow
        $result = "The solution is currently in a transitional state. Please wait a few minutes and try again (state=$appState)."
        
    }
}
catch {
    Write-Host "Error checking function status: $($_.Exception.Message)" -ForegroundColor Red
    $result = "Failed to change solution state. $($_.Exception.Message)"
}
