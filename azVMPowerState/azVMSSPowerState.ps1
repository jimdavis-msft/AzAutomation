$o = az vmss list | ConvertFrom-Json
$i = az vmss list-instances --resource-group $o[0].resourceGroup --name $o[0].name | ConvertFrom-Json

foreach ($_ in $i)
{
   $vmi = az vmss get-instance-view --name $o[0].name --resource-group $o[0].resourceGroup --instance-id $_.instanceId | ConvertFrom-Json
   Write-Host $vmi.statuses[0].displayStatus
}
