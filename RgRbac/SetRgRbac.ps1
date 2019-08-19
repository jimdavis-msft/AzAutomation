
$userPrincipalName = "user@domain"
$connectionName = "AzureRunAsConnection"
$resourceGroupName = "RgTest"
$location = "eastus"
$roleName = "Owner"

#####################################################
# BEGIN MAIN SCRIPT PROCESSING
#####################################################

    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    # WRITE OUT THE CURRENT SUBSCRIPTION FOR LOGGING PURPOSES
    $result = Select-AzureRmSubscription -SubscriptionId $servicePrincipalConnection.SubscriptionId

    # CHECK IF RESOURCE GROUP EXISTS ALREADY
    $result = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if ($null -eq $result){
        Write-Output "Resource Group does not exist.  Creating Resource Group."
        $result = New-AzureRmResourceGroup -Name $resourceGroupName $location        
    }
    else{
        Write-Output "Resource Group exists."
    }

    # GET OUR TARGET RESOURCE GROUP AS AN OBJECT
    $rg = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    # GET OUR ROLE OBJECT
    $role = Get-AzureRmRoleDefinition -Name $roleName -ErrorAction SilentlyContinue

    # CHECK THAT A VALID ROLE NAME WAS PROVIDED
    if($null -eq $role){
        Write-Output "An invalid role name was provided. Exiting."
        Exit 1
    }

    # GET OUR SECURITY PRINCIPAL THAT WILL BE ASSIGNED TO THE ROLE
    $p = Get-AzureRmADUser -UserPrincipalName $userPrincipalName

    # CHECK THAT OBJECT EXISTS
    if($null -eq $p){
        Write-Output "Security Principal object does not exist. Exiting."
        Exit
    }   

    # CHECK IF ROLE ASSIGNMENT ALREADY EXISTS
    $result = Get-AzureRmRoleAssignment -SignInName $p.UserPrincipalName -ResourceGroupName $rg.ResourceGroupName -RoleDefinitionName $role.Name -ErrorAction SilentlyContinue

    if($null -ne $result){
        Write-Output "Role assignment already exists"
        Exit 0
    }

    # CREATE A NEW ROLE ASSIGNMENT FOR OUR SECURITY PRINCIPAL ON THE TARGET RESOURCE GROUP
    $result = New-AzureRmRoleAssignment -ResourceGroupName $resourceGroupName -SignInName $userPrincipalName -RoleDefinitionName $role.Name

Write-Output "Security Principal $userPrincipalName was granted the role $roleName on Resource Group $resourceGroupName."
