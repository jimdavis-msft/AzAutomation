workflow StopAppTier
{
    Param
    (
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

    Write-Output "Stopping resources in parallel."

    Write-Output "Stopping Azure VM Scalesets"
    $vms = Get-AzureRmResource -TagName $TagName -TagValue $TagValue | where {$_.ResourceType -like "Microsoft.Compute/virtualMachineScaleSets"}

    Foreach -Parallel ($vm in $vms){
        Write-Output "Stopping VM Scale Set $($vm.Name)";       
        $result = Stop-AzureRmVmss -VMScaleSetName $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
    }

    Write-Output "Stopping Azure VMs"
    $vms = Get-AzureRmResource -TagName $TagName -TagValue $TagValue | where {$_.ResourceType -like "Microsoft.Compute/virtualMachines"}

    Foreach -Parallel ($vm in $vms){
        Write-Output "Stopping VM $($vm.Name)";       
        $result = Stop-AzureRmVm -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
    }

    Write-Output "StopAppTier Completed."
}