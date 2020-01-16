$o = az vmss list | ConvertFrom-Json
$i = az vmss list-instances --resource-group $o[0].resourceGroup --name $o[0].name | ConvertFrom-Json

foreach ($_ in $i)
{
    Write-Host $_
}
