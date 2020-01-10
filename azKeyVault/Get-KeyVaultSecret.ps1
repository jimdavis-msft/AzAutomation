$keyVaultName = "testVault"
$secretName = "secret1"

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"}
$token = $response.Content | ConvertFrom-Json

$secret = ((Invoke-WebRequest -Uri "https://$($keyVaultName).vault.azure.net/secrets/$($secretName)?api-version=2016-10-01"  -Method GET -Headers @{Authorization="Bearer $($token.access_token)"}).content | ConvertFrom-Json)