#
# This PowerShell script provides a quick getting started text file with the information needed to
# use the deployed Azure ML Workspace for the deployment of endpoints for inference.
# 
# Parameters (provided by Loome):
# - $ResourceGroupName: The name of the resource group where ML workspace was deployed
# - $WorkspaceName: The name of the ML workspace
# - $SubscriptionId: The subscription ID where the ML workspace was deployed 

# $keepFile = 'True'

# Convert the Loome JSON string that is injected by Loome into an object 
$loome = $loome | ConvertFrom-Json

# Custom Azure RBAC role to allow only operations needed for container endpoint deployment
# Give all needed permissions for Microsoft.MachineLearningServices/workspaces/onlineEndpoints/*
$AzureMLEndpointOperatorRoleDefinition = @{
    "Name" = "Azure ML Online Endpoint Operator"
    "IsCustom" = $true
    "Description" = "Can manage Azure Machine Learning Online Endpoints within a specific workspace, but cannot delete or modify the workspace itself."
    "Actions" = @(
        "Microsoft.MachineLearningServices/workspaces/onlineEndpoints/*",
        "Microsoft.MachineLearningServices/workspaces/environments/*",
        "Microsoft.MachineLearningServices/workspaces/read"
    )
    "NotActions" = @(
        "Microsoft.MachineLearningServices/workspaces/delete",
        "Microsoft.MachineLearningServices/workspaces/write",
        "Microsoft.Resources/deployments/write"
    )
    "AssignableScopes" = @(
        "/subscriptions/$($SubscriptionId)"
    )
}

try {
    Write-Host "Starting the creation of the getting started info file, including updating the RBAC roles for the workspace..."
    Write-Host "Workspace: $WorkspaceName"
    Write-Host ""

    # Check if Azure PowerShell (Az) module is installed
    $azModule = Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue
    if ($null -eq $azModule) {
        Write-Host "Installing Azure PowerShell module..."
        Install-Module -Name Az -Force
        Write-Host "Azure PowerShell module installed successfully."
    } else {
        Write-Host "Azure PowerShell module is already installed."  
    }

    # Connect to Azure using the managed identity of the VM or service deploying this script
    Write-Host "Logging in to Azure using managed identity..."
    Connect-AzAccount -Identity
    Write-Host "Logged in successfully."

    # Select the subscription
    Write-Host "Selecting subscription..."
    Select-AzSubscription -SubscriptionId $SubscriptionId
    Write-Host "Subscription selected successfully."

    # Create the custom role if it doesn't exist
    Write-Host "Checking for existing custom role definition..."
    $existingRole = Get-AzRoleDefinition -Name "Azure ML Online Endpoint Operator" -ErrorAction SilentlyContinue
    Write-Host "Existing role definition check completed."
    if ($null -eq $existingRole) {
        Write-Host "Creating custom role definition..."
        $roleDefinitionJson = $AzureMLEndpointOperatorRoleDefinition | ConvertTo-Json -Depth 10
        $tempRoleFile = "AzureMLEndpointOperatorRole.json"
        Set-Content -Path $tempRoleFile -Value $roleDefinitionJson -Force
        New-AzRoleDefinition -InputFile $tempRoleFile
        Remove-Item -Path $tempRoleFile -Force
    } else {
        Write-Host "Custom role definition already exists."
    }

    # Add the resource group scope to the AssignableScopes of the custom role, if not already present
    $roleDefinition = Get-AzRoleDefinition -Name "Azure ML Online Endpoint Operator"
    if (!$roleDefinition.AssignableScopes.Contains("/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)")) {
        Write-Host "Adding resource group scope to the AssignableScopes of the custom role..."
        $roleDefinition.AssignableScopes.Add("/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)")
        Write-Host "Updating the role definition with new AssignableScopes..."
        Set-AzRoleDefinition -Role $roleDefinition
        Write-Host "AssignableScopes updated."
    } else {
        Write-Host "Resource group scope already present in AssignableScopes."
    }
    ### TO-DO: What happens with all the stale role assignments if we keep adding scopes for resource groups that are not needed anymore? <------------------------------------------------------!!!!!!!!!!!!!!!!!!!!!!!!! TO-DO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

<#
    # Check if the project Owners role assigned, and if not, assign it
    Write-Host "Checking for existing role assignments..."
    ## First we check all Owners from the Loome project definition
    foreach ($owner in $loome.Project.Owners) {
        $ownerName = $owner.Name
        $roleAssignment = Get-AzRoleAssignment -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)" -RoleDefinitionName "Azure ML Online Endpoint Operator" -ErrorAction SilentlyContinue | Where-Object { $_.SignInName -eq $ownerName -or $_.DisplayName -eq $ownerName }
        if ($null -eq $roleAssignment) {
            Write-Host "No existing role assignment found for $ownerName. Creating role assignment..."
            # Assign the role to the owner
            Write-Host "Getting ObjectId for $ownerName"
            $userObjectId = (Get-AzADUser -SignInName $ownerName).Id
            Write-Host "ObjectId for $ownerName is $userObjectId"
            Write-Host "Assigning role to $ownerName"
            New-AzRoleAssignment -ObjectId $userObjectId -RoleDefinitionName "Azure ML Online Endpoint Operator" -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)"
            Write-Host "Role assignment created for $ownerName."
        } else {
            Write-Host "Existing role assignment found for $ownerName."
        }
    }

    # Check if the project Contributors role assigned, and if not, assign it
    foreach ($contributor in $loome.Project.Contributors) {
        $contributorName = $contributor.Name
        $roleAssignment = Get-AzRoleAssignment -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)" -RoleDefinitionName "Azure ML Online Endpoint Operator" -ErrorAction SilentlyContinue | Where-Object { $_.SignInName -eq $contributorName -or $_.DisplayName -eq $contributorName }
        if ($null -eq $roleAssignment) {
            Write-Host "No existing role assignment found for $contributorName. Creating role assignment..."
            # Assign the role to the contributor
            Write-Host "Getting ObjectId for $contributorName"
            $userObjectId = (Get-AzADUser -SignInName $contributorName).Id
            Write-Host "ObjectId for $contributorName is $userObjectId"
            Write-Host "Assigning role to $contributorName"
            New-AzRoleAssignment -ObjectId $userObjectId -RoleDefinitionName "Azure ML Online Endpoint Operator" -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)"
            Write-Host "Role assignment created for $contributorName."
        } else {
            Write-Host "Existing role assignment found for $contributorName."
        }
    }

    # Check if the project Readers role assigned, and if not, assign it
    foreach ($reader in $loome.Project.Readers) {
        $readerName = $reader.Name
        $roleAssignment = Get-AzRoleAssignment -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)" -RoleDefinitionName "Azure ML Online Endpoint Operator" -ErrorAction SilentlyContinue | Where-Object { $_.SignInName -eq $readerName -or $_.DisplayName -eq $readerName }
        if ($null -eq $roleAssignment) {
            Write-Host "No existing role assignment found for $readerName. Creating role assignment..."
            # Assign the role to the reader
            Write-Host "Getting ObjectId for $readerName"
            $userObjectId = (Get-AzADUser -SignInName $readerName).Id
            Write-Host "ObjectId for $readerName is $userObjectId"
            Write-Host "Assigning role to $readerName"
            New-AzRoleAssignment -ObjectId $userObjectId -RoleDefinitionName "Azure ML Online Endpoint Operator" -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)"
            Write-Host "Role assignment created for $readerName."
        } else {
            Write-Host "Existing role assignment found for $readerName."
        }
    }
#>
    # Write the getting started info to a text file
    Write-Host "Creating the getting started info file..."
    $fileName = "GettingStartedInfo_$WorkspaceName.txt"

   $filecontent = @"
Getting Started with Azure ML Workspace Endpoints
=================================================
This Azure Machine Learning Workspace has been configured to allow the deployment of endpoints for inference.
You can use the Azure ML CLI or the Azure ML SDK to deploy container endpoints for inference using this information:

- Workspace Name: $WorkspaceName
- Resource Group: $ResourceGroupName
- Subscription ID: $SubscriptionId

For detailed information, see: 

https://learn.microsoft.com/azure/machine-learning/how-to-deploy-managed-online-endpoints

An example to get started with the Azure ML CLI:
------------------------------------------------
# Install Azure CLI if not already installed, by going to 
#   https://learn.microsoft.com/cli/azure/install-azure-cli
# Install Azure ML CLI extension if not already installed
az extension add --name ml --yes
# Log in to Azure
az login
# Set the subscription context
az account set --subscription $SubscriptionId

# Example commands to deploy a container endpoint:
----------------------------------------
# Set the workspace context
az configure --defaults group=$ResourceGroupName workspace=$WorkspaceName
# Deploy a container endpoint
az ml online-endpoint create --name <endpoint-name> --file <endpoint-configuration-file>.yaml
# Deploy a model to the endpoint
az ml online-deployment create --endpoint-name <endpoint-name> --name <deployment-name> --file <deployment-configuration-file>.yaml
# Set the deployment as the default for the endpoint
az ml online-endpoint update --name <endpoint-name> --set traffic='{ "blue": 100 }'
# Test the endpoint
az ml online-endpoint invoke --name <endpoint-name> --request-file <input-request-file>.json
# Delete the endpoint
az ml online-endpoint delete --name <endpoint-name>

Have fun!
"@

    # Convert the file content to JSON format by escaping special characters
    Write-Host "Converting the file content to JSON format..."
    $filecontentJson = $filecontent `
        -replace '\\', '\\\\' `
        -replace '"', '\"' `
        -replace "`r`n", '\n' `
        -replace "`n", '\n'
    
    Write-Host "Creating the JSON result string..."
    $result = "{""fileName"":""$($fileName)"", ""fileContent"":""$($filecontentJson)""}"
}
catch {
    Write-Host "Unable to generate the text file: " $_.Exception.Message
}
