workflow StartAppTier
{
    Param(
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
    
    Write-Output "Starting resources for tier in parallel."
    Write-Output "Starting Azure VM Scalesets"
    $vms = Get-AzVmss | Where-Object {$_.Tags[$TagName] -eq $TagValue}
    
    Foreach -Parallel ($vm in $vms){
        Write-Output "Starting VM Scale Set $($vm.Name)";       
        $result = Start-AzVmss -VMScaleSetName $vm.Name -ResourceGroupName $vm.ResourceGroupName
    }

    Write-Output "Starting Azure VMs"
    $vms = Get-AzVm -Status| Where-Object {$_.Tags[$TagName] -eq $TagValue} | Where-Object {$_.PowerState -eq 'VM deallocated'}

    Foreach -Parallel ($vm in $vms){
        Write-Output "Starting VM $($vm.Name)";       
        $result = Start-AzVm -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName
    }

    Write-Output "StartAppTier Completed."
}