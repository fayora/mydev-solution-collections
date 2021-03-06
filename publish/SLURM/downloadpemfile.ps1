$containerName = "sshkeyholder"
$filename = "schedulernodeaccesskey.pem"

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
    if (-Not (Get-Module -ListAvailable -Name Az.Storage)) {
        Install-Module -Name Az.Storage -Repository PSGallery -Force
    }

    # Connect to the Azure account using a managed identity
    Connect-AzAccount -Identity

    # Set context for current subscription
    Set-AzContext -Subscription $subscriptionId

    # Get the storage account (with the assumption that we would have only one storage account in the resource group)
    $storageAccountName = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName).StorageAccountName

    # Get the storage account access key (key1)
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName | Where-Object {$_.KeyName -eq "key1"}).Value

    # Create the context of target storage account
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

    # Open the blob storage container
    $storageContainer = Get-AzStorageContainer -Name $containerName -Context $storageContext

    # Download the content of the pem file
    $sourceBlob = $storageContainer.CloudBlobContainer.GetBlockBlobReference($fileName)
    $fileContent = $sourceBlob.DownloadText()

    # Disconnect account after use
    Disconnect-AzAccount

    # Assign value  to $result so it can be return to the UI
    $result = "{""fileName"":""$($downloadFileName)"", ""fileContent"":""$($fileContent.Replace("`r`n", "\n"))""}"
}
catch {
    Write-Host "Unable to download the pem file." $_.Exception.Message
}