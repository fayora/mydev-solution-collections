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

    # Install the Az.Functions module if not already installed
    if (-not (Get-Module -ListAvailable -Name Az.Functions)) {
        Install-Module -Name Az.Functions -Force -Scope CurrentUser
    }

    # Set the context for Azure authentication
    ## Connect to azure account via managed identity
    Connect-AzAccount -Identity

    ## Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Find the Function App
    $functionApp = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId | Where-Object { $_.Name -like 'loome-budget-*' } | Select-Object -First 1

    if (-not $functionApp) {
        Write-Error "No Budget Enforcement solution found in resource group $resourceGroupName."
        exit 1
    }

    $appName = $functionApp.Name
    $functionName = "BudgetEnforcement" 

    # Get the current state of the function (Enabled/Disabled)
    $appSettings = Get-AzFunctionAppSetting -Name $appName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId
    $disableSetting = "AzureWebJobs.${functionName}.Disabled"
    $isDisabled = $appSettings[$disableSetting] -eq '1' -or $appSettings[$disableSetting] -eq 'true'
        if ($isDisabled) {
            # The function is currently disabled
            $result = "{""code"":""Failed"", ""message"":""Disabled"", ""isOngoing"": false}" 
        } else {
            # The function is currently enabled
            $result = "{""code"":""OK"", ""message"":""Enabled"", ""isOngoing"": false}" 
        }
}
catch {
    $result = "{""code"":""Failed"", ""message"":""Unable to determine the status of this solution. Please try again in a few minutes."", ""isOngoing"": false}" 
}