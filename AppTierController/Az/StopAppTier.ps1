workflow StopAppTier
{
    Param(
        [Parameter(Mandatory=$true)][Int]$Tier,
        [Parameter(Mandatory=$false)][string]$TagName = "autoShutdown",
        [Parameter(Mandatory=$false)][string]$ConnectionName = "AzureRunAsConnection"
    )

    Write-Output "Using parameters:"
    #$TagName = "autoShutdown"
    $TagValue = $Tier
    #$connectionName = "AzureRunAsConnection"

    Write-Output "TagName == $($TagName)"
    Write-Output "TagValue == $($TagValue)"
    Write-Output "ConnectionName == $($ConnectionName)"

    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $ConnectionName         

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

    Write-Output "Stopping resources in parallel."

    Write-Output "Stopping Azure VM Scalesets"

    Foreach -Parallel ($vm in $vms){
        Write-Output "Stopping VM Scale Set $($vm.Name)";       
        $result = Stop-AzVmss -VMScaleSetName $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
    }

    Write-Output "Stopping Azure VMs"
    $vms = Get-AzVm -Status | Where-Object {$_.Tags[$TagName] -eq $TagValue} | Where-Object {$_.PowerState -eq 'VM running'}

    Foreach -Parallel ($vm in $vms){
        Write-Output "Stopping VM $($vm.Name)";       
        $result = Stop-AzVm -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
    }

    Write-Output "StopAppTier Completed."
}