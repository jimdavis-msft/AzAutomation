$subscriptionId = 'YOUR SUBSCRIPTION ID GOES HERE'

# CHECK THAT AN AUTHENTICATION CONTEXT EXISTS FOR POWERSHELL
$context = Get-AzContext

if ($null -eq $context)
{
    $a = Connect-AzAccount
}

# CHECK THAT THE AZURE CLI HAS A VALID ACCOUNT CONTEXT
$result = az account show | ConvertFrom-Json

if ($null -eq $result)
{
   az login
}

# CHECK THAT THE POWERSHELL CONTEXT IS SET FOR THE TARGET SUBSCRIPTION
if ($context.Name.Contains($subscriptionId) -eq $false)
{
   Select-AzSubscription -Subscription $subscriptionId
}

# CHECK THAT THE AZURE CLI CONTEXT IS SET FOR THE TARGET SUBSCRIPTION
$o = az account show | ConvertFrom-Json

if ($o.id -ne $subscriptionId)
{
   az account set --subscription $subscriptionId
}

$o = az vmss list | ConvertFrom-Json
$i = az vmss list-instances --resource-group $o[0].resourceGroup --name $o[0].name | ConvertFrom-Json

foreach ($_ in $i)
{
   $vmi = az vmss get-instance-view --name $o[0].name --resource-group $o[0].resourceGroup --instance-id $_.instanceId | ConvertFrom-Json
   Write-Host "InstanceId == $($_.instanceId); Status == $($vmi.statuses[0].displayStatus);"
}
