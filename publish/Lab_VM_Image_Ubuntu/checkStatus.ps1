# This script provides the status of the VM. The status can be one of the following:
# *** Return Object ***
#	code: string
#		Possible values are:
#			OK 			- Green Icon
#			Information - Blue Icon
#			Warning 	- Yellow Icon
#			Failed 		- Red Icon
#
#	message: string
#		Return messsage that is displayed on the UI and has same color as code property.
#
#	isOngoing: boolean (Optional)
#		An icon is added with style to indicate that this status is ongoing.

# For troubleshooting, you can set $keepFile to 'True' to prevent the script from deleting itself after execution.
$keepFile = 'True'

try {

    # Get an access token for managed identities for Azure resources
    $response = Invoke-WebRequest `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -Headers @{Metadata = "true" }
    $content = $response.Content | ConvertFrom-Json
    $access_token = $content.access_token

    
    # Use the access token to get resource information for the VM
    $currentStatusResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/instanceView?api-version=2021-03-01" `
        -Method GET `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" } 
    
    # $currentStatusContent = $currentStatusResponse.Content | ConvertFrom-Json
    # $vmStatus = $currentStatusContent.statuses[1].displayStatus

    # Parse the JSON response to get the VM status for PowerState
    $currentStatusContent = $currentStatusResponse.Content | ConvertFrom-Json

    # For troubleshooting: output to screen all statuses
    # foreach ($status in $currentStatusContent.statuses) {
    #     Write-Output "Code: $($status.code), DisplayStatus: $($status.displayStatus)"
    # }

    $vmStatus = ($currentStatusContent.statuses | Where-Object { $_.code -like "PowerState/*" }).displayStatus

    # Parse the JSON response to get the VM status for OSState -- if it exists and the value is generalized, then the image is being captured
    $osStatus = ($currentStatusContent.statuses | Where-Object { $_.code -like "OSState/*" }).displayStatus
    
    if ($vmStatus -eq "VM running") {
        # The VM is currently running
        $result = "{""code"":""OK"", ""message"":""Running"", ""isOngoing"": false}" 
    } elseif ($vmStatus -eq "VM deallocated") {
        # The VM is currently stopped -- this can be because it is turned off or it is being captured as an image. If the OSState is generalized, then we know it is being captured, otherwise it is turned off.
        if ($osStatus -eq "VM generalized") {
            # The VM has been generalized. Check the gallery image version to determine whether the image
            # capture is still in progress, has succeeded, or has failed.
            $galleryVersionStatus = $null
            try {
                $cleanGalleryId = ([string]$imageGalleryResourceId -replace "`r`n|`r|`n", "").Trim()
                $cleanLabName   = [string]$labName -replace "`r`n|`r|`n", ""

                $galleryRegex = '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Compute/galleries/([^/]+)$'
                if (-not [string]::IsNullOrWhiteSpace($cleanGalleryId) -and $cleanGalleryId -match $galleryRegex) {
                    $galSubId  = $Matches[1]
                    $galRgName = $Matches[2]
                    $galName   = $Matches[3]

                    # Derive definition name using the same sanitization as captureVMImage.ps1
                    $defName = ($cleanLabName -replace '[^A-Za-z0-9_.-]', '-') -replace '-{2,}', '-'
                    $defName = $defName.Trim('_', '-', '.')
                    if ([string]::IsNullOrWhiteSpace($defName)) { $defName = "lab-image" }
                    if ($defName.Length -gt 80) { $defName = $defName.Substring(0, 80).TrimEnd('_', '-', '.') }

                    $versionsUri = "https://management.azure.com/subscriptions/$galSubId/resourceGroups/$galRgName/providers/Microsoft.Compute/galleries/$galName/images/${defName}/versions?api-version=2023-07-03"
                    $versionsResponse = Invoke-WebRequest `
                        -Uri $versionsUri `
                        -Method GET `
                        -ContentType "application/json" `
                        -Headers @{ Authorization = "Bearer $access_token" } `
                        -SkipHttpErrorCheck

                    if ($versionsResponse.StatusCode -ge 200 -and $versionsResponse.StatusCode -lt 300) {
                        $versions = ($versionsResponse.Content | ConvertFrom-Json).value
                        if ($versions.Count -gt 0) {
                            if ($versions | Where-Object { $_.properties.provisioningState -in @("Creating", "Updating", "Replicating") }) {
                                $galleryVersionStatus = "Creating"
                            } elseif ($versions | Where-Object { $_.properties.provisioningState -eq "Succeeded" }) {
                                $galleryVersionStatus = "Succeeded"
                            } elseif ($versions | Where-Object { $_.properties.provisioningState -in @("Failed", "Canceled") }) {
                                $galleryVersionStatus = "Failed"
                            }
                        }
                    }
                }
            } catch {
                # If the gallery check fails for any reason, fall back to the generic captured state
                $galleryVersionStatus = $null
            }

            if ($galleryVersionStatus -eq "Creating") {
                $result = "{""code"":""Information"", ""message"":""Creating image"", ""isOngoing"": true}"
            } elseif ($galleryVersionStatus -eq "Succeeded") {
                $result = "{""code"":""OK"", ""message"":""Image successfully created"", ""isOngoing"": false}"
            } elseif ($galleryVersionStatus -eq "Failed") {
                $result = "{""code"":""Warning"", ""message"":""Image was not created but VM is not deleted"", ""isOngoing"": false}"
            } else {
                # Fallback: gallery not accessible, definition not yet created, or no versions found yet
                $result = "{""code"":""Warning"", ""message"":""Image Captured"", ""isOngoing"": false}"
            }
        } else {
            $result = "{""code"":""Failed"", ""message"":""Stopped"", ""isOngoing"": false}" 
        }
    } elseif ($vmStatus -eq "VM stopped") {
        # The VM was incorrectly shut down by the user from the operating system, so stopping it and showing a message
        $statusChangeResponse = Invoke-WebRequest `
        -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$deployedVirtualMachineName/deallocate?api-version=2021-03-01" `
        -Method POST `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $access_token" }
        $result = "{""code"":""Information"", ""message"":""Deallocating"", ""isOngoing"": false}"
    } else {
        # The VM is currently transitioning
        $result = "{""code"":""Information"", ""message"":""Transitioning"", ""isOngoing"": true}" 
    }
    New-Object -Property @{ReturnText = "$result" } -TypeName psobject
}
catch {
    Write-Error "Unable to determine the status of this VM. Please try again in a few minutes." $_.Exception.Message
}