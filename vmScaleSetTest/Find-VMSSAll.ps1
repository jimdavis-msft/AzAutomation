Function Get-VMSSAll([string]$TagName, [string]$TagValue)
{
    $result = New-Object System.Collections.ArrayList

    # GET CURRENT LOGON USER SECURITY CONTEXT
    $currentAzContext = Get-AzContext

    if ($null -eq $currentAzContext)
    {
        Write-Host "Please authenticate this session before continuing."
        return $null
    }

    $token = Get-AzCachedAccessToken

    $o = ((Invoke-WebRequest -Uri "https://management.azure.com/subscriptions/$($currentAzContext.Subscription.Id)/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2019-03-01"  -Method GET -Headers @{Authorization="Bearer $($token)"}).content | ConvertFrom-Json)

    foreach ($_ in $o)
    {
        if ($_.value.tags.$TagName -eq $TagValue)
        {
            $result.Add($_)
        }
    }

    return $result
}

function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'
  
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}

function Get-AzBearerToken()
{
    $ErrorActionPreference = 'Stop'
    ('Bearer {0}' -f (Get-AzCachedAccessToken))
}


# ----------------- AzureRM module compatible below

function Get-AzureRmCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'
  
    if(-not (Get-Module AzureRm.Profile)) {
        Import-Module AzureRm.Profile
    }
    $azureRmProfileModuleVersion = (Get-Module AzureRm.Profile).Version
    # refactoring performed in AzureRm.Profile v3.0 or later
    if($azureRmProfileModuleVersion.Major -ge 3) {
        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        if(-not $azureRmProfile.Accounts.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
        }
    } else {
        # AzureRm.Profile < v3.0
        $azureRmProfile = [Microsoft.WindowsAzure.Commands.Common.AzureRmProfileProvider]::Instance.Profile
        if(-not $azureRmProfile.Context.Account.Count) {
            Write-Error "Ensure you have logged in before calling this function."    
        }
    }
  
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}

function Get-AzureRmBearerToken()
{
    $ErrorActionPreference = 'Stop'
    ('Bearer {0}' -f (Get-AzureRmCachedAccessToken))
}

Function Set-ScaleRuleCount ([string]$rgName, [string]$name, [int] $count)
{
    $out = az monitor autoscale update -g $rgName --name $name --count $count
}
Function Force-ScaleOperation ([string]$rgName, [string]$vmssName, [int] $count)
{
    $out = az vmss scale -g $rgName --name $vmssName --new-capacity $count
}

Function Get-InstanceCount ($resourceGroupName, $vmssName){
    #return ((az vmss list-instances -g $resourceGroupName --name $vmssName | ConvertFrom-Json) | Where-Object -Property provisioningState -eq "Succeeded").count
    return ((az vmss list-instances -g $resourceGroupName --name $vmssName | ConvertFrom-Json)).count
}

Function Wait-ScalingOperation ([int] $count){

    [bool]$bContinue = $True
    while ($bContinue){
        $c = Get-InstanceCount -resourceGroupName $vmss.resourceGroup -vmssName $vmss.name
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

$o = Get-VMSSAll -TagName ProjCode -TagValue Default

Write-Host "There are $($o.count) VM scale sets in the subscription."