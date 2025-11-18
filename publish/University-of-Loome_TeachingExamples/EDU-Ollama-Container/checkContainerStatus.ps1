# Make sure these two vars are at the top
$executionPolicy = 'RemoteSigned'
# Set for troubleshooting the script
$keepFile = 'True'

try {
    # TIP: Get-Command <cmdlet_you_are_after> | select name, module
    if (-not (Get-Module -Name Az.App -ListAvailable)) {
        Install-Module -Name Az.App -AllowClobber -Scope CurrentUser -Force -ErrorAction Stop
    }
    
    # Set the context for Azure authentication
    ## Connect to azure account via managed identity
    Connect-AzAccount -Identity
    
    ## Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Get the current state of the container app using PowerShell
    $currentState = Get-AzContainerAppRevision -ContainerAppName $containerAppName -ResourceGroupName $resourceGroupName | Select-Object -ExpandProperty RunningState
    Write-Host $currentState

    if ($currentState -match "Running") {
        # The container is currently running
        $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}"
        Write-Host "The container app is currently running."

    } elseif ($currentState -eq "Stopped") {
        # The container is currently stopped
        $result = "{""code"":""Failed"", ""message"":""Stopped"", ""isOngoing"": false}"
        Write-Host "The container app is currently stopped."

    } else {
        # The container is currently transitioning
        $result = "{""code"":""Information"", ""message"":""Transitioning"", ""isOngoing"": true}"
        Write-Host "The container app is in a transitioning state..."
    }
    $result = "$result"
}
catch {
    Write-Host "Unable to determine the status of this container app. Please try again in a few minutes. " + $_.Exception.Message
}