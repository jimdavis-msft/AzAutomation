param(
    [Parameter (Mandatory=$true)][string] $resourceGroupName
)

$connectionName = "AzureRunAsConnection"

#####################################################
# BEGIN MAIN SCRIPT PROCESSING
#####################################################

    try
    {   
        Write-Output "Getting Automation Connection"
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
        Write-Output $servicePrincipalConnection
        
        "Logging in to Azure..."
        Connect-AzAccount `
            -ServicePrincipal `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
            -Tenant $servicePrincipalConnection.TenantId
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
    $result = Select-AzSubscription -SubscriptionId $servicePrincipalConnection.SubscriptionId

    # CHECK IF RESOURCE GROUP EXISTS ALREADY
    $result = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if ($null -eq $result){
        Write-Output "Resource Group does not exist.  Exiting."
    }
    else{
        Write-Output "Resource Group exists."
    }

    # GET OUR TARGET RESOURCE GROUP AS AN OBJECT
    $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    Remove-AzResourceGroup -Id $rg.ResourceId -Force

    Write-Output "Resource Group removed successfully."