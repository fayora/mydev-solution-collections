param($Timer)
$Action = $env:BE_Action

Write-Host "Starting Budget Enforcement. Action: $Action"

# Authenticate used Managed Identity (Function App automatically handles this with Connect-AzAccount -Identity in profile)

$tagName = 'Loome-Budget Status'
$tagValue = 'Exceeded'

Write-Host "Searching for resources with tag: $tagName = $tagValue"
$resources = Get-AzResource -TagName $tagName -TagValue $tagValue

if ($null -eq $resources -or $resources.Count -eq 0) {
    Write-Host "No resources found with the budget exceeded tag."
    return
}

    foreach ($res in $resources) {
        Write-Host "Processing $($res.Name) ($($res.ResourceType))"
        try {
            if ($Action -eq 'stop') {
                if ($res.ResourceType -eq 'Microsoft.Compute/virtualMachines') {
                    $status = Get-AzVM -ResourceGroupName $res.ResourceGroupName -Name $res.Name -Status
                    $statusAz = $status.Statuses[1].DisplayStatus
                    if ($statusAz -eq 'VM running') {
                        Write-Host "Stopping VM $($res.Name)..."
                        Stop-AzVM -ResourceGroupName $res.ResourceGroupName -Name $res.Name -Force -NoWait
                    } else {
                        Write-Host "VM $($res.Name) is in state $($statusAz). Skipping..."
                    }
                }
            } elseif ($Action -eq 'deleteAll' -or $Action -eq 'deleteComputeOnly') {
                # Safe-guards: Do not remove NSGs or VNets
                if ($res.ResourceType -in @('Microsoft.Network/networkSecurityGroups', 'Microsoft.Network/virtualNetworks')) {
                    Write-Host "Skipping deletion of $($res.ResourceType) $($res.Name) (Global Exclusion)"
                    continue
                }

                # Compute Only Logic: Skip Storage Accounts and Managed Disks
                 if ($Action -eq 'deleteComputeOnly' -and ($res.ResourceType -eq 'Microsoft.Storage/storageAccounts' -or $res.ResourceType -eq 'Microsoft.Compute/disks')) {
                     Write-Host "Skipping deletion of $($res.ResourceType) $($res.Name) (Action is Delete Compute Only)"
                     continue
                }

                Write-Host "Deleting resource..."
                Remove-AzResource -ResourceId $res.ResourceId -Force -ErrorAction Stop
            } else {
                Write-Host "Unknown action: $Action. No operation performed."
            }
        } catch {
            Write-Error "Failed to process resource $($res.Name): $_"
        }
    }
