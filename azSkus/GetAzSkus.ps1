$skus = az vm list-skus | ConvertFrom-Json
$eastskus = $skus | Where-Object -Property locations -EQ eastus
$centralskus = $skus | Where-Object -Property locations -EQ centralus

foreach ($_ in $eastskus)
{
    Write-Host "$($_.name)"
    
    foreach ($c in $_.capabilities)
    {
        if ($c.name -eq "AcceleratedNetworkingEnabled")
        {
            Write-Host "    $($c.name) : $($c.value) "
        }
    }
}

Write-Host ""
Write-Host "***** centralus *****"
Write-Host ""

foreach ($_ in $centralskus)
{
    Write-Host "$($_.name)"
    
    foreach ($c in $_.capabilities)
    {
        if ($c.name -eq "AcceleratedNetworkingEnabled")
        {
            Write-Host "    $($c.name) : $($c.value) "
        }
    }
}
