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

    # Pick up its public IP address name
    $publicIpAddressName = ($schedulerNetworkInterface.IpConfigurations.PublicIpAddress.Id.Split("/"))[-1]

    # Get the public IP address of the scheduler
    $schedulerPublicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName).IpAddress

    # Disconnect account after use
    Disconnect-AzAccount

    # Assign value  to $result so it can be return to the UI
    $result = "ssh hpcadmin@" + $schedulerPublicIpAddress + " -i <private key>"
}
catch {
    Write-Host "Unable to get ssh detail of the scheduler node." $_.Exception.Message
}