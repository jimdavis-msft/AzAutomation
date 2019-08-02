
$connectionName = "AzureRunAsConnection"

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

    $result = Select-AzureRmSubscription -SubscriptionId $servicePrincipalConnection.SubscriptionId

    $result = Get-AzureRmResourceGroup -Name "RGTest" -ErrorAction SilentlyContinue

    

Write-Output $result
Write-Output "Completed successfully"