# This script captures the deployed VM into an Azure Compute Gallery image version.
# It deallocates and generalizes the VM, then creates or updates an image definition and version.
# It requires that the following variables are provided by the ARM template outputs:
# - subscriptionId
# - resourceGroupName
# - deployedVirtualMachineName
# - imageGalleryResourceId
# - labName

# For troubleshooting, you can set $keepFile to 'True' to prevent the script from deleting itself after execution.
$keepFile = 'True'

$PSStyle.OutputRendering = 'PlainText'

$ErrorActionPreference = "Stop"

function Get-ManagedIdentityAccessToken {
    Write-Host "Getting access token for managed identity..."
    $response = Invoke-WebRequest `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -Headers @{ Metadata = "true" }

    return (($response.Content | ConvertFrom-Json).access_token)
}
 
function Invoke-AzureRest {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [AllowNull()][object]$Body = $null
    )

    Write-Host "Invoking Azure REST API: $Method $Uri"
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $params = @{
        Uri                = $Uri
        Method             = $Method
        Headers            = $headers
        ContentType        = "application/json"
        SkipHttpErrorCheck = $true
    }

    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 25)
    }

    $response = Invoke-WebRequest @params

    $content = $null
    if ($response.Content) {
        try { $content = $response.Content | ConvertFrom-Json } catch { $content = $response.Content }
    }

    return [PSCustomObject]@{
        StatusCode = [int]$response.StatusCode
        Headers    = $response.Headers
        Content    = $content
    }
}

function Get-AzureResponseErrorMessage {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [string]$Activity = "Azure request"
    )

    $statusCode = $Response.StatusCode
    $errorCode = $null
    $errorMessage = $null

    if ($Response.Content -is [string]) {
        $errorMessage = $Response.Content
    }
    elseif ($null -ne $Response.Content) {
        if ($Response.Content.error) {
            $errorCode = $Response.Content.error.code
            $errorMessage = $Response.Content.error.message
        }

        if (-not $errorMessage -and $Response.Content.message) {
            $errorMessage = $Response.Content.message
        }

        if (-not $errorMessage) {
            try {
                $errorMessage = ($Response.Content | ConvertTo-Json -Depth 25 -Compress)
            }
            catch {
                $errorMessage = [string]$Response.Content
            }
        }
    }

    if (-not $errorMessage) {
        $errorMessage = "HTTP $statusCode"
    }

    if ($errorCode) {
        return "$Activity failed. HTTP $statusCode. Code: $errorCode. Message: $errorMessage"
    }

    return "$Activity failed. HTTP $statusCode. Message: $errorMessage"
}

function Assert-AzureSuccessResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][string]$Activity
    )

    if ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300) {
        throw (Get-AzureResponseErrorMessage -Response $Response -Activity $Activity)
    }
}

function Wait-AzureOperation {
    param(
        [Parameter(Mandatory = $true)][object]$InitialResponse,
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [Parameter(Mandatory = $true)][string]$Activity,
        [int]$TimeoutSeconds = 3600,
        [int]$PollSeconds = 10
    )

    Write-Host "Waiting for $Activity to complete..."

    Assert-AzureSuccessResponse -Response $InitialResponse -Activity $Activity

    # Poll whenever async headers are present (Azure returns 201 or 202 with these headers
    # for long-running operations; absence means synchronous completion).
    $asyncUri = @($InitialResponse.Headers["Azure-AsyncOperation"])[0]
    if (-not $asyncUri) {
        $asyncUri = @($InitialResponse.Headers["Location"])[0]
    }

    if (-not $asyncUri) {
        return
    }

    $startTime = Get-Date
    while ($true) {
        Start-Sleep -Seconds $PollSeconds

        if (((Get-Date) - $startTime).TotalSeconds -gt $TimeoutSeconds) {
            throw "$Activity timed out after $TimeoutSeconds seconds."
        }

        $poll = Invoke-AzureRest -Method "GET" -Uri $asyncUri -AccessToken $AccessToken
        $status = $poll.Content.status

        # Some Azure operations (e.g. gallery image versions via Location header) return the
        # resource directly with properties.provisioningState instead of a top-level status field.
        if (-not $status -and $null -ne $poll.Content.properties) {
            $status = $poll.Content.properties.provisioningState
        }

        if ($status -eq "Succeeded") {
            return
        }

        if ($status -eq "Failed" -or $status -eq "Canceled") {
            $errorMessage = $poll.Content.error.message
            # Gallery image version failures surface the error in properties.statusMessage
            if (-not $errorMessage -and $null -ne $poll.Content.properties -and $poll.Content.properties.statusMessage) {
                try {
                    $statusMsg = $poll.Content.properties.statusMessage
                    if ($statusMsg -is [string]) {
                        $parsed = $statusMsg | ConvertFrom-Json -ErrorAction SilentlyContinue
                        $errorMessage = if ($parsed.error.message) { $parsed.error.message } else { $statusMsg }
                    } else {
                        $errorMessage = $statusMsg | ConvertTo-Json -Compress
                    }
                } catch {
                    $errorMessage = [string]$poll.Content.properties.statusMessage
                }
            }
            if (-not $errorMessage) { $errorMessage = "$Activity failed with status: $status." }
            throw $errorMessage
        }

        if (-not $status) {
            if ($poll.StatusCode -ge 200 -and $poll.StatusCode -lt 300) {
                return
            }
            throw (Get-AzureResponseErrorMessage -Response $poll -Activity "$Activity polling")
        }
    }
}

function Get-SanitizedImageDefinitionName {
    param([Parameter(Mandatory = $true)][string]$Name)

    Write-Host "Sanitizing image definition name from lab name: $Name"

    $clean = ($Name -replace '[^A-Za-z0-9_.-]', '-')
    $clean = $clean -replace '-{2,}', '-'
    $clean = $clean.Trim('_', '-', '.')

    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = "lab-image"
    }

    if ($clean.Length -gt 80) {
        $clean = $clean.Substring(0, 80).TrimEnd('_', '-', '.')
        if ([string]::IsNullOrWhiteSpace($clean)) {
            $clean = "lab-image"
        }
    }

    return $clean
}

function Get-NextImageVersion {
    param([Parameter(Mandatory = $true)][object]$VersionList)

    $currentMajor = (Get-Date).Year
    $currentMinor = (Get-Date).Month
    $semverRegex = '^([0-9]+)\.([0-9]+)\.([0-9]+)$'
    $maxPatch = -1

    Write-Host "Determining next image version based on existing versions in the gallery..."

    foreach ($v in $VersionList) {
        if ($v.name -match $semverRegex) {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            $patch = [int]$Matches[3]

            if ($major -eq $currentMajor -and $minor -eq $currentMinor -and $patch -gt $maxPatch) {
                $maxPatch = $patch
            }
        }
    }

    if ($maxPatch -lt 0) {
        return "$currentMajor.$currentMinor.0"
    }

    return "$currentMajor.$currentMinor.$($maxPatch + 1)"
}

try {
    foreach ($requiredVariableName in @('subscriptionId', 'resourceGroupName', 'deployedVirtualMachineName', 'imageGalleryResourceId', 'labName')) {
        $requiredVariable = Get-Variable -Name $requiredVariableName -ErrorAction SilentlyContinue
        if ($null -eq $requiredVariable -or [string]::IsNullOrWhiteSpace([string]$requiredVariable.Value)) {
            throw "The required variable '$requiredVariableName' was not provided by the deployment outputs."
        }
    }

    # Strip newlines and carriage returns from all deployment variables
    $subscriptionId = [string]$subscriptionId -replace "`r`n|`r|`n", ""
    $resourceGroupName = [string]$resourceGroupName -replace "`r`n|`r|`n", ""
    $deployedVirtualMachineName = [string]$deployedVirtualMachineName -replace "`r`n|`r|`n", ""
    $imageGalleryResourceId = [string]$imageGalleryResourceId -replace "`r`n|`r|`n", ""
    $labName = [string]$labName -replace "`r`n|`r|`n", ""

    $accessToken = Get-ManagedIdentityAccessToken

    $vmUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}?api-version=2023-09-01"
    $vm = Invoke-AzureRest -Method "GET" -Uri $vmUri -AccessToken $accessToken
    Assert-AzureSuccessResponse -Response $vm -Activity "VM lookup"

    $vmLocation = $vm.Content.location
    if (-not $vmLocation) {
        throw "Unable to determine the VM location."
    }

    $imageGalleryResourceId = $imageGalleryResourceId.Trim()
    
    $galleryRegex = '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Compute/galleries/([^/]+)$'
    if ($imageGalleryResourceId -notmatch $galleryRegex) {
        throw "The gallery resource ID is invalid: '$imageGalleryResourceId'. Expected format: /subscriptions/{id}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name}"
    }

    $gallerySubscriptionId = $Matches[1]
    $galleryResourceGroupName = $Matches[2]
    $galleryName = $Matches[3]

    $definitionName = Get-SanitizedImageDefinitionName -Name $labName

    # Ensure the VM is running before executing the in-guest deprovision command.
    # If it is stopped/deallocated, start it first.
    $instanceViewUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}/instanceView?api-version=2023-09-01"
    $instanceView = Invoke-AzureRest -Method "GET" -Uri $instanceViewUri -AccessToken $accessToken
    Assert-AzureSuccessResponse -Response $instanceView -Activity "VM instance view"
    $powerState = ($instanceView.Content.statuses | Where-Object { $_.code -like "PowerState/*" }).code

    if ($powerState -ne "PowerState/running") {
        Write-Host "VM is not running (state: $powerState). Starting VM before deprovision..."
        $startUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}/start?api-version=2023-09-01"
        $startResponse = Invoke-AzureRest -Method "POST" -Uri $startUri -AccessToken $accessToken
        Wait-AzureOperation -InitialResponse $startResponse -AccessToken $accessToken -Activity "VM start"
    }

    # Run waagent deprovision inside the VM to generalise the OS before capture.
    # The agent is disabled on this VM so we will never receive a completion response —
    # fire the command and wait 30 seconds for waagent to finish before moving on.
    $runCommandUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}/runCommand?api-version=2023-09-01"
    $runCommandBody = @{
        commandId = "RunShellScript"
        script    = @("sudo waagent -deprovision+user -force && shutdown -h now")
    }
    Write-Host "Sending waagent deprovision command..."
    Invoke-AzureRest -Method "POST" -Uri $runCommandUri -AccessToken $accessToken -Body $runCommandBody | Out-Null
    Write-Host "Waiting 30 seconds for waagent deprovision to complete..."
    Start-Sleep -Seconds 30

    $deallocateUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}/deallocate?api-version=2023-09-01"
    $deallocateResponse = Invoke-AzureRest -Method "POST" -Uri $deallocateUri -AccessToken $accessToken
    Wait-AzureOperation -InitialResponse $deallocateResponse -AccessToken $accessToken -Activity "VM deallocation"

    $generalizeUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/${deployedVirtualMachineName}/generalize?api-version=2023-09-01"
    try {
        $generalizeResponse = Invoke-AzureRest -Method "POST" -Uri $generalizeUri -AccessToken $accessToken
        Wait-AzureOperation -InitialResponse $generalizeResponse -AccessToken $accessToken -Activity "VM generalization"
    }
    catch {
        if ($_.Exception.Message -notmatch "already generalized|Generalized") {
            throw
        }
    }

    $definitionUri = "https://management.azure.com/subscriptions/$gallerySubscriptionId/resourceGroups/$galleryResourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/${definitionName}?api-version=2023-07-03"

    $definitionLookup = Invoke-AzureRest -Method "GET" -Uri $definitionUri -AccessToken $accessToken
    $definitionExists = $true
    if ($definitionLookup.StatusCode -eq 404) {
        $definitionExists = $false
    }
    elseif ($definitionLookup.StatusCode -lt 200 -or $definitionLookup.StatusCode -ge 300) {
        throw (Get-AzureResponseErrorMessage -Response $definitionLookup -Activity "Image definition lookup")
    }

    if (-not $definitionExists) {
        $definitionBody = @{
            location   = $vmLocation
            properties = @{
                osType           = "Linux"
                osState          = "Generalized"
                hyperVGeneration = "V2"
                identifier       = @{
                    publisher = "loome"
                    offer     = $definitionName
                    sku       = "latest"
                }
            }
        }

        $createDefResponse = Invoke-AzureRest -Method "PUT" -Uri $definitionUri -AccessToken $accessToken -Body $definitionBody
        Wait-AzureOperation -InitialResponse $createDefResponse -AccessToken $accessToken -Activity "Image definition creation"
    }

    $versionsUri = "https://management.azure.com/subscriptions/$gallerySubscriptionId/resourceGroups/$galleryResourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/${definitionName}/versions?api-version=2023-07-03"
    $versionList = Invoke-AzureRest -Method "GET" -Uri $versionsUri -AccessToken $accessToken
    Assert-AzureSuccessResponse -Response $versionList -Activity "Image version list"
    $nextVersion = Get-NextImageVersion -VersionList $versionList.Content.value

    $sourceVmId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName"
    $imageVersionUri = "https://management.azure.com/subscriptions/$gallerySubscriptionId/resourceGroups/$galleryResourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/${definitionName}/versions/${nextVersion}?api-version=2023-07-03"

    $imageVersionBody = @{
        location   = $vmLocation
        properties = @{
            publishingProfile = @{
                targetRegions = @(
                    @{
                        name                 = $vmLocation
                        regionalReplicaCount = 1
                        storageAccountType   = "Standard_LRS"
                    }
                )
            }
            storageProfile = @{
                source = @{
                    virtualMachineId = $sourceVmId
                }
            }
        }
    }

    $createVersionResponse = Invoke-AzureRest -Method "PUT" -Uri $imageVersionUri -AccessToken $accessToken -Body $imageVersionBody
    Assert-AzureSuccessResponse -Response $createVersionResponse -Activity "Image version creation"

    $result = "Image capture initiated. Gallery: $galleryName | Definition: $definitionName | Version: $nextVersion | The image version is being replicated in the background and will be available shortly."
    New-Object -Property @{ ReturnText = $result } -TypeName psobject
}
catch {
    $message = $_.Exception.Message
    if (-not $message) {
        $message = "Unknown error during image capture."
    }

    Write-Error "Capture VM Image failed: $message"
    New-Object -Property @{ ReturnText = "Capture VM Image failed: $message" } -TypeName psobject
}
