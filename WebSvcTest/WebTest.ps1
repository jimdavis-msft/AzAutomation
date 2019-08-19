param(
    [string]$clientSecret,
    [string]$uRI,
    [string]$tenantId,
    [string]$clientId,
    [string]$appScope,
    [string]$successResult
)

Write-Host ""
Write-Host "Verifying that the web service api management is up and running."
Write-Host "Calling $($uRI)"

# GET BEARER TOKEN FOR WEB API AUTHENTICATION

$endPoint = "https://login.microsoftonline.com/$($tenantId)/oauth2/v2.0/token"
$scope = "api://$($appScope)/.default"
$grantType = "client_credentials"

$result = $null
$result = curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$($clientId)&scope=$($scope)&client_secret=$($clientSecret)&grant_type=$($grantType)" $endPoint
$result = $result.split(",")
$result = $result[3].replace('"access_token":"', "")
$accessToken = $result.replace('"}',"")

$result = "Authorization: bearer $($accessToken)"

$result = $null
$result = curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$($clientId)&scope=$($scope)&client_secret=$($clientSecret)&grant_type=$($grantType)" $endPoint
$result = $result.split(",")
$result = $result[3].replace('"access_token":"', "")
$accessToken = $result.replace('"}',"")

#curl -X GET -H $result $uRI
$r = curl -X GET -H "Authorization: Bearer $($accessToken)" "$uRI"

if ($null -ne $r)
{
    if ($r -eq $successResult){
        Write-Host "API call ($($uRI)) succeeded."
    }
    else {
        Write-Host "API call ($($uRI)) failed."
        Exit 1
    }
}
else {
    Write-Host "API call failed."
    Exit 1
}

Write-Host 0