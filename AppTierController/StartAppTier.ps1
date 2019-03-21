workflow StartAppTier
{
    Param
    (
        [Parameter(Mandatory=$true)][Int] $Tier,
        [Parameter(Mandatory=$false)][string]$TagName = "autoStart",
        [Parameter(Mandatory=$false)][string]$ConnectionName = "AzureRunAsConnection"
    )

    Write-Output "Using parameters:"
    #$TagName = "autoStart"
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
    
    Write-Output "Starting resources for tier in parallel."
    Write-Output "Starting Azure VM Scalesets"
    $vms = Get-AzureRmResource -TagName $TagName -TagValue $TagValue | where {$_.ResourceType -like "Microsoft.Compute/virtualMachineScaleSets"}
    
    Foreach -Parallel ($vm in $vms){
        Write-Output "Starting VM Scale Set $($vm.Name)";       
        $result = Start-AzureRmVmss -VMScaleSetName $vm.Name -ResourceGroupName $vm.ResourceGroupName
    }

    Write-Output "Starting Azure VMs"
    $vms = Get-AzureRmResource -TagName $TagName -TagValue $TagValue | where {$_.ResourceType -like "Microsoft.Compute/virtualMachines"}

    Foreach -Parallel ($vm in $vms){
        Write-Output "Starting VM $($vm.Name)";       
        $result = Start-AzureRmVm -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName
    }

    Write-Output "StartAppTier Completed."
}