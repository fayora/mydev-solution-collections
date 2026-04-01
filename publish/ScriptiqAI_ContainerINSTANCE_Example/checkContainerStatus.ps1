# Make sure these two vars are at the top
$executionPolicy = 'RemoteSigned'
# Set for troubleshooting the script
# $keepFile = 'True'

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
        # The container is currently running
        $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}"
        Write-Host "The container instance is currently running."

    } elseif ($currentState -eq "Stopped") {
        # The container is currently stopped
        $result = "{""code"":""Failed"", ""message"":""Stopped"", ""isOngoing"": false}"
        Write-Host "The container instance is currently stopped."

    } elseif ($currentState -eq "Failed") {
        # The container has failed
        $result = "{""code"":""Failed"", ""message"":""Failed"", ""isOngoing"": false}"
        Write-Host "The container instance has failed."

    } else {
        # The container is currently transitioning (Pending, Starting, etc.)
        $result = "{""code"":""Information"", ""message"":""$currentState"", ""isOngoing"": true}"
        Write-Host "The container instance is in a transitioning state: $currentState"
    }
    $result = "$result"
}
catch {
    Write-Host "Unable to determine the status of this container instance. Please try again in a few minutes. " + $_.Exception.Message
}