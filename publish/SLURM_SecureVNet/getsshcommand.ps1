# Get the trimmed name of the Solution Collection from the Resource Group name
$stringArray = $resourceGroupName.Split("-")
$solutionCollectionIndex = $stringArray.Count - 2
$solutionCollectionName = $stringArray[$solutionCollectionIndex].Replace("_", "").Replace(".", "")

# Specify the name of the private key file by using the name of the Solution Collection, so that it is easy to identify
$downloadFileName = $solutionCollectionName + "-cluster.pem"

try {
    # Only install modules that are used to avoid agent timeout (3mins)
    if (-Not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Install-Module -Name Az.Accounts -Repository PSGallery -Force
    }
    if (-Not (Get-Module -ListAvailable -Name Az.Network)) {
        Install-Module -Name Az.Network -Repository PSGallery -Force
    }

    # Connect to azure account via managed identity
    Connect-AzAccount -Identity

    # Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Get the network interface detail of the scheduler node
    $networkInterfaces = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName
    $schedulerNetworkInterface = $networkInterfaces | Where-Object {($_.VirtualMachine.Id.Split("/"))[-1] -match "scheduler-*"}

    # Get the private IP address of the scheduler
    $schedulerPrivateIpAddress = $schedulerNetworkInterface.IpConfigurations.PrivateIpAddress

    # Disconnect account after use
    Disconnect-AzAccount

    # Assign value  to $result so it can be return to the UI
    $result = "ssh $ClusterAdminUsername@" + $schedulerPrivateIpAddress + " -i $downloadFileName"
}
catch {
    Write-Host "Unable to get ssh detail of the scheduler node." $_.Exception.Message
}