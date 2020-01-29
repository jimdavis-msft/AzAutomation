param(
    [Parameter (Mandatory=$True)][string] $Subscription,
    [Parameter (Mandatory=$True)][string] $ResourceGroup
)

Function Disable-VmssMonitor ([string]$ResourceGroup)
{
    $autoScale = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroup
    $autoScale.Enabled = $false 
    $result = Add-AzAutoscaleSetting -ResourceGroupName $ResourceGroup -InputObject $autoScale
}

Function Enable-VmssMonitor ([string]$ResourceGroup)
{
    $autoScale = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroup
    $autoScale.Enabled = $true 
    $result = Add-AzAutoscaleSetting -ResourceGroupName $ResourceGroup -InputObject $autoScale
}

Function Set-VmssInstanceCount ([string]$ResourceGroupName, [string]$VmssName, [int]$count)
{
    $v = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName
    $v.Sku.Capacity = $count
    $result = Update-AzVmss -VMScaleSetName $VmssName -ResourceGroupName $ResourceGroupName -VirtualMachineScaleSet $v
}

# GET THE CURRENT USER SECURITY CONTEXT
$context = Get-AzContext

# VERIFY THAT A VALID SECURITY CONTEXT IS SET
if ($null -eq $context)
{
    $context = Connect-AzAccount -Subscription $Subscription
}

# SET THE TARGET SUBSCRIPTION
$result = Set-AzContext -Subscription $Subscription

# GET ALL VM SCALE SETS IN THE SUBSCRIPTION
$vmss = Get-AzResource | Where-Object {$_.ResourceType -like "Microsoft.Compute/virtualMachineScaleSets"}
$count = 1
# DISABLE THE MONITOR FOR EACH SCALE SET AND SET THE INSTANCE COUNT TO 1
foreach($_ in $vmss) 
{
    Write-Host "Disabling VMSS monitor for $($_.name) and setting instance count to $($count)."
    Disable-VmssMonitor -ResourceGroup $_.ResourceGroupName
    Set-VmssInstanceCount -ResourceGroupName $_.ResourceGroupName -VmssName $_.Name -count $count
}

# ENABLE THE MONITOR FOR EACH SCALE SET AND SET THE INSTANCE COUNT TO 3
foreach($_ in $vmss) 
{
    Write-Host "Enabling VMSS monitor for $($_.name) and setting instance count to $($count)."
    Enable-VmssMonitor -ResourceGroup $_.ResourceGroupName
    Set-VmssInstanceCount -ResourceGroupName $_.ResourceGroupName -VmssName $_.Name -count $count
}

# ITERATE OVER EACH SCALE SET AND SHOW THE CURRENT STATUS AND INSTANCE COUNT
foreach($_ in $vmss) 
{
    $o = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroup
    $v = Get-AzVmss -ResourceGroupName $ResourceGroup -VMScaleSetName $v.Name

    if ($o.Enabled)
    {
        Write-Host "VM Scale Set monitor $($o.Name) is currently enabled."
    }
    else 
    {
        Write-Host "VM Scale Set monitor $($o.Name) is currently disabled."
    }

    Write-Host "VM Scale Set $($v.name) currently has $($v.Sku.capacity) instances."
}