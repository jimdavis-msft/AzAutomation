Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $SubscriptionId,
    [string] [Parameter(Mandatory=$true)] $VMssName
)

function Initialize-VMssModel ([string]$Name, [string]$RGName){

    $rg = Get-AzureRmResourceGroup -Name $RGName
    $vmss = Get-AzureRmVmss -ResourceGroupName $rg.ResourceGroupName -VMScaleSetName $Name
    $vmss.Overprovision = $false
    $vmss = Update-AzureRmVmss -VirtualMachineScaleSet $vmss -VMScaleSetName $VMssName -ResourceGroupName $rg.ResourceGroupName
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

# VERIFY THAT RESOURCE GROUP EXISTS
$result = Get-AzureRmResource -ResourceGroupName $ResourceGroupName

if($null -eq $result){
    Write-Output "Resource Group $($ResourceGroupName) does not exist."
    return 1
}


# VERIFY THAT TARGET VM SCALESET  EXISTS
$result = Get-AzureRmVmss -VMScaleSetName $VMssName -ResourceGroupName $ResourceGroupName

if($null -eq $result){
    Write-Output "VM Scaleset $($VMssName) does not exist."
    return 1
}

Write-Output "Initializing VM scale set model."
Initialize-VMssModel -Name $VMssName -RGName $ResourceGroupName

Write-Output "Done"




