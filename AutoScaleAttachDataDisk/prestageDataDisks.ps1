Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $SubscriptionId,
    [string] [Parameter(Mandatory=$true)] $StartIndex,
    [string] [Parameter(Mandatory=$true)] $Count
)

function stageDataDisk([int] $startId, [int]$count, [string]$ResourceGroupName){

    $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName

    for($i = 0; $i -lt $count;$i++){
        $targetDiskName = "mdisk$($i+$startId)"
        Write-Host "Prestaging $($targetDiskName)"
        $SnapShotSourceDisk = "mdisk0Snap"
        $snapShot = Get-AzureRmSnapshot -ResourceGroupName $rg.ResourceGroupName -SnapshotName $SnapShotSourceDisk

        $disk = $null
        $disk = Get-AzureRmDisk -ResourceGroupName $rg.ResourceGroupName -Name $targetDiskName -ErrorAction SilentlyContinue

        if($null -eq $disk){
            $diskConfig = New-AzureRmDiskConfig -Location $rg.Location -AccountType Premium_LRS -CreateOption Copy -SourceResourceId $snapShot.Id
            $newDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName $targetDiskName
            Write-Host "Disk $($newDisk.Name) created successfully."
        }
        else
        {
            Write-Host "Disk already exists."
        }
    }
}

# DETERMINE IF USER IS LOGGED INTO AZURE
#
$context = Get-AzureRmContext

if($null -eq $context)
{
	Write-Output "Creating credentials for cloud account."
    $cred = Get-Credential
	$result = Login-AzureRmAccount -Credential $cred
    $context = Get-AzureRmContext
}
else
{
	Write-Output "Session already logged in as $($context.Account.Id)."
}

# SELECT THE CORRECT AZURE SUBSCRIPTION FOR THE DEPLOYMENT
#
if(!($context.Subscription.Id -like "*$($SubscriptionId)*"))
{
	Write-Output "Setting Azure Subscription"
	Select-AzureRmSubscription -Subscription $SubscriptionId
}

stageDataDisk -startId $StartIndex -count $Count -ResourceGroupName $ResourceGroupName