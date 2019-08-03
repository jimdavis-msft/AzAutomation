param(
    [Parameter(Mandatory=$True)][string] $vmssName,
    [Parameter(Mandatory=$True)][string] $resourceGroupName,
    [Parameter(Mandatory=$True)][string] $autoScaleRuleName
)

Function Set-ScaleRuleCount ([string]$rgName, [string]$name, [int] $count)
{
    $out = az monitor autoscale update -g $rgName --name $name --count $count
}
Function Force-ScaleOperation ([string]$rgName, [string]$vmssName, [int] $count)
{
    $out = az vmss scale -g $rgName --name $vmssName --new-capacity $count
}

Function Get-InstanceCount ($resourceGroupName, $vmssName){
    return ((az vmss list-instances -g $resourceGroupName --name $vmssName | ConvertFrom-Json)).count
}

Function Wait-ScalingOperation ([int] $count){

    [bool]$bContinue = $True
    while ($bContinue){
        #$count =  ((az vmss list-instances -g $vmss.resourceGroup --name $vmss.name | ConvertFrom-Json) | Where-Object -Property provisioningState -eq "Succeeded").count
        $c =  ((az vmss list-instances -g $vmss.resourceGroup --name $vmss.name | ConvertFrom-Json)).count
        $waitTime = 15
        if ($c -ne $count){
            Write-Host "Current instance count is $($c) but waiting for $($count).  Waiting for $($waitTime) seconds."
            Start-Sleep $waitTime
        }
        else
        {
            $bContinue = $False
            Write-Host "Current instance count is $($c). "
        }
    }
}
Function Remove-VmssInstances ([string]$resourceGroupName, [string] $vmssName, [int]$count){
    $instances =  ((az vmss list-instances -g $vmss.resourceGroup --name $vmss.name | ConvertFrom-Json) | Where-Object -Property "provisioningState" -eq "Succeeded")

    if (($instances.count - $count) -gt 0){
        for ([int]$i = 0; $i -lt $count; $i++){
            $out = az vmss delete-instances -g $resourceGroupName --name $vmssName --instance-ids $instances[$i].instanceId --no-wait
        }        
    }
    else{
        Write-Host "Cannot remove $($count) instance(s) from scalset $($vmssName) as it has $($result.count) instance(s) in a Succeeded state." -ForegroundColor Red
        exit
    }
}

$color = "Cyan"
$vmss = az vmss show -g $resourceGroupName --name $vmssName| ConvertFrom-json

# GET AUTOSCALE RULE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json

if ($null -eq $r){
    Write-Host "Autoscale rule not found."
    Exit
}

$autoscaleMin = $r.profiles.capacity.minimum
$autoscaleStart = $r.profiles.capacity.minimum

Write-Host "Autoscale minimum instance count is $($autoscaleMin)." -ForegroundColor $color
$iCount = Get-InstanceCount -resourceGroupName $resourceGroupName -vmssName $vmssName
Write-Host "Current capacity for VM Scaleset $($vmss.name) is $($iCount)." -ForegroundColor $color

# WAIT FOR AUTOSCALE RULE TO FORCE A STEADY STATE TO TARGET
if ($iCount -ne $autoscaleMin){
    Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)."  -ForegroundColor $color
    Wait-ScalingOperation -count ($autoscaleMin)
}

# SET THE NUMBER OF INSTANCES THAT SHOULD BE DELETED HERE
$n = 1
Write-Host "Deleting $($n) instance(s)." -ForegroundColor $color
Remove-VmssInstances -resourceGroupName $vmss.resourceGroup -vmssName $vmss.name -count $n
Wait-ScalingOperation -count ($autoscaleMin - $n)

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)." -ForegroundColor $color
Wait-ScalingOperation -count ($autoscaleMin)

# FORCE A SCALE OUT OPERATION
$n = ([int]$autoscaleMin + 1)
Write-Host "Forcing autoscaling event to require $($n) instances." -ForegroundColor $color
Force-ScaleOperation -rgName $vmss.resourceGroup -vmssName $vmss.name -count $n

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)." -ForegroundColor $color
Wait-ScalingOperation -count ($autoscaleMin)

# CHANGE AUTOSCALE TARGET HIGHER
$n = ([int]$autoscaleMin + 2)
Write-Host "Setting autoscaling rule to require $($n) instances." -ForegroundColor $color
Set-ScaleRuleCount -rgName $vmss.resourceGroup -name $autoScaleRuleName -count $n

# REFRESH AUTOSCALE OBJECT AND GET NEW MIN VALUE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Wait-ScalingOperation -count $autoscaleMin

# UPDATE AUTOSCALE RULE TO 1 INSTANCE
[int] $n = 1
Write-Host "Setting autoscaling rule to require 1 instance." -ForegroundColor $color
Set-ScaleRuleCount -rgName $vmss.resourceGroup -name $autoScaleRuleName -count $n
# REFRESH AUTOSCALE OBJECT AND GET NEW MIN VALUE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Wait-ScalingOperation -count $autoscaleMin

$vmss = az vmss show -g $vmss.resourceGroup --name $vmssName| ConvertFrom-json
Write-Host "Current capacity for VM Scaleset $($vmss.name) is $($vmss.sku.capacity)." -ForegroundColor $color

# SET AUTOSCALE RULE MIN BACK TO STARTING VALUE
Write-Host "Setting autoscale rule back to staring minimum value of $($autoscaleStart)." -ForegroundColor $color
Set-ScaleRuleCount -rgName $vmss.resourceGroup -name $autoScaleRuleName -count $autoscaleStart

# REFRESH AUTOSCALE OBJECT AND GET NEW MIN VALUE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Wait-ScalingOperation -count $autoscaleMin