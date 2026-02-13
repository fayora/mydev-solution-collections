# This script toggles the enabled/disabled state of the Budget Enforcement function in the specified resource group.

# Comment or uncomment the line below to keep or remove (default) script file that Loome runs.
$keepFile="True"

# Install the Az.Functions module if not already installed
if (-not (Get-Module -ListAvailable -Name Az.Functions)) {
    Install-Module -Name Az.Functions -Force -Scope CurrentUser
}

# Find the Function App
$functionApp = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId | Where-Object { $_.Name -like 'loome-budget-*' } | Select-Object -First 1

if (-not $functionApp) {
    Write-Error "No Budget Enforcement solution found in resource group $resourceGroupName."
    exit 1
}

try {
    $appName = $functionApp.Name
    $functionName = "BudgetEnforcement"
    # The setting to disable a function is separate from the function name in settings
    $disableSetting = "AzureWebJobs.${functionName}.Disabled"

    # Check current state
    $appSettings = Get-AzFunctionAppSetting -Name $appName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId
    $isDisabled = $appSettings[$disableSetting] -eq '1' -or $appSettings[$disableSetting] -eq 'true'

    if ($isDisabled) {
        Write-Host "Solution '$functionName' is currently DISABLED. Enabling..."
        # To enable, we can remove the setting or set it to 0/false
        Update-AzFunctionAppSetting -Name $appName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId -AppSetting @{ $disableSetting = "0" } -Force
        $result = "Solution enabled."
    }
    else {
        Write-Host "Solution '$functionName' is currently ENABLED. Disabling..."
        Update-AzFunctionAppSetting -Name $appName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId -AppSetting @{ $disableSetting = "1" } -Force
        $result = "Solution disabled."
    }
} catch {
    $result = "Failed to change solution state. $($_.Exception.Message)"
}
