$vmssName = "vmssModel"
$resourceGroupName = "_SCRATCH"


$rg = Get-AzureRmResourceGroup -Name $resourceGroupName

$vmss = Get-AzureRmVmss -ResourceGroupName $rg.ResourceGroupName -VMScaleSetName $vmssName
$vmss.Overprovision = $false
$vmss = Update-AzureRmVmss -VirtualMachineScaleSet $vmss -VMScaleSetName $vmssName -ResourceGroupName $rg.ResourceGroupName

$vmss.sku.Capacity = 1
$vmss = Update-AzureRmVmss -VirtualMachineScaleSet $vmss -VMScaleSetName $vmssName -ResourceGroupName $rg.ResourceGroupName

$vms = Get-AzureRmVmssVM -ResourceGroupName $rg.ResourceGroupName -VMScaleSetName $vmss.Name
$vmssVM = Get-AzureRmVmssVM -ResourceGroupName $rg.ResourceGroupName -VMScaleSetName $vmss.Name -InstanceId $vms[0].InstanceId

$targetDiskName = "mdisk$($vmssVM.InstanceId)"
$SnapShotSourceDisk = "mdisk0Snap"
$snapShot = Get-AzureRmSnapshot -ResourceGroupName $rg.ResourceGroupName -SnapshotName $SnapShotSourceDisk

$diskConfig = New-AzureRmDiskConfig -Location $rg.Location -AccountType Premium_LRS -CreateOption Copy -SourceResourceId $snapShot.Id
$newDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName $targetDiskName
    
$vmssVM = Add-AzureRmVmssVMDataDisk -VirtualMachineScaleSetVM $vmssVM -Lun 1 -CreateOption Attach -ManagedDiskId $newDisk.Id
Update-AzureRmVmssVM -VirtualMachineScaleSetVM $vmssVM



