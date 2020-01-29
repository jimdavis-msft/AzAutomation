$context = Get-AzContext

if ($null -eq $context)
{
    $a = Connect-AzAccount
}

$v = Get-AzVM -Status

foreach ($_ in $v)
{
    Write-Host "$($_.Name) == $($_.Powerstate)"
}