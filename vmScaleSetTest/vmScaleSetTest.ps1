param(
    [string] $vmssName,
    [string] $resourceGroupName,
    [string] $autoScaleRuleName
)

Function Set-ScaleRuleCount ([string]$rgName, [string]$vmssName, [int] $n)
{
    Write-Host "Setting autoscaling rule to require $($n) instances."
    
    # Edit autoscale rule to reflect new count
    $out = az monitor autoscale update -g $rg.name --name $r.name --count $n
}
Function Force-ScaleOperation ([int] $n)
{
    Write-Host "Forcing autoscaling event to require $($n) instances."
    $out = az vmss scale -g $vmss.resourceGroup --name $vmss.name --new-capacity $n
}

Function Get-InstanceCount ($resourceGroupName, $vmssName){
    return ((az vmss list-instances -g $resourceGroupName --name $vmssName | ConvertFrom-Json)).count
}

Function Wait-ScalingOperation ([int] $count){

    [bool]$bContinue = $True
    while ($bContinue){
        #$count =  ((az vmss list-instances -g $vmss.resourceGroup --name $vmss.name | ConvertFrom-Json) | Where-Object -Property provisioningState -eq "Succeeded").count
        $c =  ((az vmss list-instances -g $vmss.resourceGroup --name $vmss.name | ConvertFrom-Json)).count
        $waitTime = 5
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
        Write-Host "Cannot remove $($count) instance(s) from scalset $($vmssName) as it only has $($result.count) instance(s)."
    }
}

$vmss = az vmss show -g $resourceGroupName --name $vmssName| ConvertFrom-json

# GET AUTOSCALE RULE
#$rules = az monitor autoscale list -g $rg.name
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum
$autoscaleStart = $r.profiles.capacity.minimum

Write-Host "Autoscale minimum instance count is $($autoscaleMin)."
$iCount = Get-InstanceCount -resourceGroupName $resourceGroupName -vmssName $vmssName
Write-Host "Current capacity for VM Scaleset $($vmss.name) is $($iCount)."

# WAIT FOR AUTOSCALE RULE TO FORCE A STEADY STATE TO TARGET
if ($iCount -ne $autoscaleMin){
    Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)."
    Wait-ScalingOperation -count ($autoscaleMin)
}

# SET THE NUMBER OF INSTANCES THAT SHOULD BE DELETED HERE
$n = 1
Write-Host "Deleting $($n) instance(s)."
Remove-VmssInstances -resourceGroupName $vmss.resourceGroup -vmssName $vmss.name $n
Wait-ScalingOperation -count ($autoscaleMin - $n)

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)."
Wait-ScalingOperation -count ($autoscaleMin)

# FORCE A SCALE OUT OPERATION
Force-ScaleOperation ($autoscaleMin + 1)
Wait-ScalingOperation -count ($autoscaleMin + 1)

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Write-Host "Waiting for autoscale rule to force instance count to $($autoscaleMin)."
Wait-ScalingOperation -count ($autoscaleMin)

# CHANGE AUTOSCALE TARGET HIGHER
Set-ScaleRuleCount -rgName $vmss.resourceGroup -vmssName $vmss.name -n ($autoscaleMin + 2)

# REFRESH AUTOSCALE OBJECT AND GET NEW MIN VALUE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Wait-ScalingOperation -count $autoscaleMin

# UPDATE AUTOSCALE RULE TO 1 INSTANCE
Set-ScaleRuleCount -rgName $vmss.resourceGroup -vmssName $vmss.name -n 1
# REFRESH AUTOSCALE OBJECT AND GET NEW MIN VALUE
$r = az monitor autoscale show -g $vmss.resourceGroup --name $autoScaleRuleName | ConvertFrom-Json
$autoscaleMin = $r.profiles.capacity.minimum

# WAIT FOR AUTOSCALE RULE TO FORCE COUNT BACK TO TARGET
Wait-ScalingOperation -count $autoscaleMin

$vmss = az vmss show -g $vmss.resourceGroup --name $vmssName| ConvertFrom-json
Write-Host "Current capacity for VM Scaleset $($vmss.name) is $($vmss.sku.capacity)."
Write-Host "Setting autoscale rule back to staring minimum value of $($autoscaleStart)."