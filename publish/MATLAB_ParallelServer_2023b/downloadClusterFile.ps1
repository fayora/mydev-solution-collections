$fileShareName = "shared"
$downloadFileName = "parallelCluster.mlsettings"
$filePath = "cluster/" + $downloadFileName

try {
    # Only install modules that are used to avoid agent timeout (3mins)
    if (-Not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Install-Module -Name Az.Accounts -Repository PSGallery -Force
    }
    if (-Not (Get-Module -ListAvailable -Name Az.Storage)) {
        Install-Module -Name Az.Storage -Repository PSGallery -Force
    }

    # Connect to the Azure account using a managed identity
    Connect-AzAccount -Identity

    # Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Get the storage account access key (key1)
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccount | Where-Object {$_.KeyName -eq "key1"}).Value

    # Create the context of target storage account
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey

    # Get a read-only SAS URL for the file and make it valid for 30 minutes
    $StartTime = Get-Date
    $EndTime = $StartTime.AddMinutes(30.0)
    $DownloadURL = New-AzStorageFileSASToken -ShareName $fileShareName -Path $filePath -Context $storageContext -Permission "r" -StartTime $StartTime -ExpiryTime $EndTime -FullUri

    # Disconnect account after use
    Disconnect-AzAccount

    # Assign value  to $result so it can be return to the UI
    $result = "$($DownloadURL)"
}
catch {
    Write-Host "Unable to download the cluster file: " $_.Exception.Message
}