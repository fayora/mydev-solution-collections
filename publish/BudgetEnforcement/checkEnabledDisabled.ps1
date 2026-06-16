# This script checks the current enabled/disabled state of the Budget Enforcement function and returns the status for Loome to deploy
# The status can be one of the following:
# *** Return Object ***
#	code: string
#		Possible values are:
#			OK 			- Green Icon
#			Information - Blue Icon
#			Warning 	- Yellow Icon
#			Failed 		- Red Icon
#
#	message: string
#		Return messsage that is displayed on the UI and has same color as code property.
#
#	isOngoing: boolean (Optional)
#		An icon is added with style to indicate that this status is ongoing.

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
        # The function is currently Running
        Write-Host "The function $functionName is currently $appState." -ForegroundColor Green
        $result = "{""code"":""OK"", ""message"":""Enabled"", ""isOngoing"": false}" 
    }
    elseif ($appState -eq "Stopped") {
        # The function is currently Stopped
        Write-Host "The function $functionName is currently $appState." -ForegroundColor Yellow
        $result = "{""code"":""Failed"", ""message"":""Disabled"", ""isOngoing"": false}"
    }
    else {
         # The function is in an unexpected state
        Write-Host "The function $functionName is in an unexpected state: state=$appState" -ForegroundColor Yellow
        $result = "{""code"":""Warning"", ""message"":""$appState"", ""isOngoing"": false}"
    }
}
catch {
    Write-Host "Error checking function status: $($_.Exception.Message)" -ForegroundColor Red
    $result = "{""code"":""Warning"", ""message"":""Unable to determine the status of this solution. Please try again in a few minutes."", ""isOngoing"": false}" 
}