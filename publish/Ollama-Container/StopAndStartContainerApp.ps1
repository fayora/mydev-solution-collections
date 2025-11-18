# This script first checks if the container app is running or is stopped, and based on that it starts or stops the app.
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
        Write-Host "Stopping container app..."
        Stop-AzContainerApp -Name $containerAppName -ResourceGroupName $resourceGroupName
        $outputText = "The container app is currently stopping."
    } elseif ($currentState -eq "Stopped") {
        Write-Host "Starting container app..."
        Start-AzContainerApp -Name $containerAppName -ResourceGroupName $resourceGroupName
        $outputText = "The container app is currently starting."
    } else {
        Write-Host "Container app is in a transitioning state..."
        $outputText = "The container app is currently in a transitioning state: $currentState. Wait a couple of minutes and try again."
    }
    $result = "$outputText"
}
catch {
    Write-Host "Error occurred while checking the status of the container app."
    $result = "Unable to determine the status of this container app. Please try again in a few minutes. " + $_.Exception.Message
}