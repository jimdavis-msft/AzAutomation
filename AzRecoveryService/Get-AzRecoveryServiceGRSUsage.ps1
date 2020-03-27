param(
    [parameter(Mandatory=$true)][string]$subscriptionId,
    [parameter(Mandatory=$true)][string]$resourceGroup,
    [parameter(Mandatory=$true)][string]$vaultName
)

$hello = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/instance/network?api-version=2017-08-01' -Method GET -Headers @{Metadata="true"}
if ($hello.StatusCode -ne 200)
{
    Write-Host "Cannot communicate with the metadata service."
    return 1
}

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -Method GET -Headers @{Metadata="true"}
$token = $response.Content | ConvertFrom-Json

if(($null -eq $token) -or ($token -eq ""))
{
    Write-Host "Unable to get a bearer token for the Recovery Services vault service.  Be sure the VM running this script has a System Managed identity and the Resource Group containing the Recovery Service has delegated permissions to the System Managed Account."
}

$uri = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroup)/providers/Microsoft.RecoveryServices/vaults/$($vaultName)/usages?api-version=2016-06-01"
$result = ((Invoke-WebRequest -Uri $uri -Method GET -Headers @{Authorization="Bearer $($token.access_token)"}).content) | ConvertFrom-Json

foreach ($_ in $result.value)
{
    if ($_.name.value -eq "GRSStorageUsage"){
        if (($null -eq $_.currentValue) -or ($_.currentValue -ne 0))
        {
            Write-Host "Recovery Services Value $($vaultName) in subscription $($subscriptionId) is using $($_.currentValue) bytes of GRS storage."
            return 0
        }
    }
}

Write-Host "Recovery Services Value $($vaultName) in subscription $($subscriptionId) does not appear to be using GRS storage."