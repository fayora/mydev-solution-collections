# This script first checks if the container instance is running or is stopped, and based on that it starts or stops the instance.
$executionPolicy = 'RemoteSigned'
# Set for troubleshooting the script
$keepFile = 'True'

try {
    # TIP: Get-Command <cmdlet_you_are_after> | select name, module
    if (-not (Get-Module -Name Az.ContainerInstance -ListAvailable)) {
        Install-Module -Name Az.ContainerInstance -AllowClobber -Scope CurrentUser -Force -ErrorAction Stop
    }

    # Set the context for Azure authentication
    ## Connect to azure account via managed identity
    Connect-AzAccount -Identity
    
    ## Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Get the current state of the container instance using PowerShell
    $containerGroup = Get-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerInstanceName
    $currentState = $containerGroup.InstanceViewState
    Write-Host $currentState

    if ($currentState -eq "Running") {
        Write-Host "Stopping container instance..."
        Stop-AzContainerGroup -Name $containerInstanceName -ResourceGroupName $resourceGroupName
        $outputText = "The container instance is currently stopping."
    } elseif ($currentState -eq "Stopped") {
        Write-Host "Starting container instance..."
        Start-AzContainerGroup -Name $containerInstanceName -ResourceGroupName $resourceGroupName
        $outputText = "The container instance is currently starting."
    } else {
        Write-Host "Container instance is in a transitioning state..."
        $outputText = "The container instance is currently in a transitioning state: $currentState. Wait a couple of minutes and try again."
    }
    $result = "$outputText"
}
catch {
    Write-Host "Error occurred while checking the status of the container instance."
    $result = "Unable to determine the status of this container instance. Please try again in a few minutes. " + $_.Exception.Message
}