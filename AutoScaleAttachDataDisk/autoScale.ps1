param(
    [Parameter (Mandatory=$false)][object] $WebhookData,
    [Parameter (Mandatory=$true)][string] $SnapShotSourceDisk
)

function Scale-Out([string] $VMScaleSetName, [string]$ResourceGroupName){

    $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName
    
    # GET OUR SNAPSHOT THAT WILL BE THE SOURCE OF ANY NEW DATA DISKS
    $snapShot = Get-AzureRmSnapshot -ResourceGroupName $rg.ResourceGroupName -SnapshotName $SnapShotSourceDisk
        
    $vms = Get-AzureRmVmssVM -VMScaleSetName $VMScaleSetName -ResourceGroup $rg.ResourceGroupName

    foreach($v in $vms){
        Write-Output "Checking VM instance $($v.Name) for the data disk."
        $dataDiskExists = $false

        $dataDisks = $v.StorageProfile.DataDisks

        if ($null -ne $dataDisks){
            foreach ($d in $dataDisks){
                if($d.Name -like "mdisk*"){
                    Write-Output "Found data disk on $($v.Name)"
                    Write-Output "No update action required."
                    $dataDiskExists = $true
                    break
                }
            }
        }

        if(!($dataDiskExists)){
            
            # ADD DATA DISK SINCE NOT FOUND
            Write-Output "Adding data disk on instance $($v.Name)."
            $targetDiskName = "mdisk$($v.InstanceId)"
            $newDisk = Get-AzureRmDisk -DiskName $targetDiskName -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue

            #  CREATE NEW DATA DISKS FROM SNAPSHOT IF IT DOES NOT ALREADY EXIST
            if($null -eq $newDisk){
                Write-Output "Target disk does not exist.  Creating disk from snapshot."
                $diskConfig = New-AzureRmDiskConfig -Location $rg.Location -AccountType Premium_LRS -CreateOption Copy -SourceResourceId $snapShot.Id
                $newDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName $targetDiskName
            }
            else {
                Write-Output "Target disk already exists.  Attaching pre-staged data disk."
            }

            # WAIT FOR VM INSTANCE TO BE READY FOR ATTACH
            Write-Output "Waiting for VM instance to be ready for attach."
            Wait-VMssVMUpdate -VMScaleSetName $VMScaleSetName -InstanceId $v.InstanceId -ResourceGroupName $rg.ResourceGroupName
            Write-Output "VM instance is finished updating."

            # ATTACH DATA DISK THAT WE JUST CREATED
            Write-Output "Attaching disk."
            $v = Add-AzureRmVmssVMDataDisk -VirtualMachineScaleSetVM $v -Lun 1 -CreateOption Attach -ManagedDiskId $newDisk.Id
            #Write-Output $vmssVm.StorageProfile.DataDisks

            try {
                Update-AzureRmVmssVM -VirtualMachineScaleSetVM $v #-ErrorAction SilentlyContinue
            }
            catch {
                Write-Output "Error caught while trying at update VMss instance."
                Write-Output $_.Exception.Message
                Write-Output "Please verify that the scaleset model has an implicitly created data disk before attempting to attach an external data disk."
            }
        }
    }
}

function Scale-In([string]$VMScaleSetName, [string] $ResourceGroupName){
    $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName

    # WAIT FOR VM SCALE SET PROVISIONING TO RETURN TO READY BEFORE ATTEMPTING TO REMOVE DATA DISKS
        Write-Output "Waiting for VM scale set update operation to complete."
        Wait-VMssUpdate -VMScaleSetName $VMScaleSetName -ResourceGroupName $ResourceGroupName
        Write-Output "VM scale set update operation complete."
    # REMOVE ALL UNUSED DATA DISKS
    Remove-Unmanaged $ResourceGroupName
}

function Wait-VMssUpdate([string]$VMScaleSetName, [string] $ResourceGroupName){
    [bool]$bContinue = $true
    while($bContinue){
        if(Test-VmssProvisioningState -VMScaleSetName $VMScaleSetName -ResourceGroupName $ResourceGroupName){
            break 
        }
        Start-Sleep 5
    }    
}

function Wait-VMssVMUpdate([string]$VMScaleSetName, [int]$InstanceId, [string]$ResourceGroupName){
    [bool]$bContinue = $true
    while($bContinue){
        if(Test-VMssVmInstance -VMScaleSetName $VMScaleSetName -InstanceId $InstanceId -resourceGroupName $ResourceGroupName){
            break 
        }
        Start-Sleep 5
    }    
}

function Remove-Unmanaged ([string] $ResourceGroupName){
    Write-Output "Removing unattached disks from Resource Group $($ResourceGroupName)."
    $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName

    $disks = Get-AzureRmDisk -ResourceGroupName $rg.ResourceGroupName
    foreach ($d in $disks){
        if($d.Name.ToLower() -like "mdisk*"){
            if($null -eq $d.ManagedBy){
                Write-Output "Removing disk $($d.Name)."
                Remove-AzureRmDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $d.Name -Force
            }
        }
    }
}

function Test-VmssProvisioningState ([string]$VMScaleSetName, [string]$ResourceGroupName){

    [bool]$bUseVMStatus = $true

    if($bUseVMStatus){
        $vmss = Get-AzureRmVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSetName
        foreach($_ in $vmss){
            if($_.ProvisioningState -ne "Succeeded"){
                return $false
            }
        }
        return $true
    }
    else {
        $vmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSetName
        if($vmss.ProvisioningState -eq "Succeeded"){
            return $true
        }
        else{
            return $false
        }
    }
}

function Test-VMssVmInstance ([string]$VMScaleSetName, [int]$InstanceId, [string]$resourceGroupName){

    $vm = Get-AzureRmVmssVM -VMSCaleSetName $VMScaleSetName -InstanceId $InstanceId -ResourceGroupName $resourceGroupName
    if($vm.ProvisioningState -eq "Succeeded"){
        return $true
    }
    return $false
}


#####################################################
# BEGIN MAIN SCRIPT PROCESSING
#####################################################

Write-Output "Starting autoScaleOperation."
$subscriptionId = $null
$resourceGroupName = $null
$vmssName = $null
$operationType = $null
$vmssName = $null
$targetCapacity = $null

if ($WebhookData)
{
    try{
        # Collect properties of WebhookData
        $WebhookName     =     $WebhookData.WebhookName
        $WebhookHeaders  =     $WebhookData.RequestHeader
        $WebhookBody     =     $WebhookData.RequestBody

        # Collect individual headers. Input converted from JSON.
        $Input = (ConvertFrom-Json -InputObject $WebhookBody)

        Write-Output "subscriptionId == $($Input.context.subscriptionId)"
        Write-Output "resourceGroupName == $($Input.context.resourceGroupName)"
        Write-Output "resource Name == $($Input.context.resourceName)"

        $operationType = $Input.operation
        $subscriptionId = $Input.context.subscriptionId
        $resourceGroupName = $Input.context.resourceGroupName
        $vmssName = $Input.context.resourceName
        $targetCapacity = $Input.context.newCapacity

        Write-Output -InputObject ('Runbook started from webhook {0} with type {1}.' -f $WebhookName, $Input.operation)
        Write-Output -InputObject ('Scaling from {0} to {1}.' -f $Input.context.oldCapacity, $Input.context.newCapacity)
    }
    catch{}
}
else
{
    Write-Output "Webhookdata object not received."
}

try
{
    # Get the connection "AzurePowerShellRunAsConnection "
    $azureCredential = Get-AutomationPSCredential -Name "azurePSCred"

    if($null -ne $azureCredential)
    {
        Write-Output "Attempting to authenticate as: [$($azureCredential.UserName)]."
        $result = Login-AzureRmAccount -Credential $azureCredential 
        Select-AzureRmSubscription -SubscriptionId $subscriptionId
    }
}
catch {
    Write-Output "Error getting PS Credential"
}

if($operationType.ToLower() -eq "scale out"){
    Write-Output "Scale out operation started."
    Scale-Out $vmssName $resourceGroupName
}

if($operationType.ToLower() -eq "scale in"){
    Write-Output "Scale in operation started."
    Scale-In $vmssName $resourceGroupName
}

Write-Output "Exiting autoScaleOperation."