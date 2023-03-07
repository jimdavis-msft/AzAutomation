<# 

#>

Function ConvertTo-Base64UrlString {
    <# 
        .LINK
        https://github.com/SP3269/posh-jwt
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$in
    )
    if ($in -is [string]) {
        return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($in)) -replace '\+','-' -replace '/','_' -replace '='
    }
    elseif ($in -is [byte[]]) {
        return [Convert]::ToBase64String($in) -replace '\+','-' -replace '/','_' -replace '='
    }
    else {
        throw "ConvertTo-Base64UrlString requires string or byte array input, received $($in.GetType())"
    }
}

Function New-Jwt (
    <# 
        .LINK
        https://github.com/SP3269/posh-jwt
    #>

    [Parameter(Mandatory = $True)]
    [string] $TenantId,

    [Parameter(Mandatory = $True)]
    [string] $ClientId, 

    [Parameter(Mandatory = $False)]
    [int]$ValidforSeconds = 300,

    [Parameter(Mandatory = $False)]
    [System.Security.Cryptography.X509Certificates.X509Certificate]$Cert
    )
{

    $exp = [int][double]::parse((Get-Date -Date $((Get-Date).addseconds($ValidforSeconds).ToUniversalTime()) -UFormat %s))
    $issueTime = [int][double]::parse((Get-Date -Date $((Get-Date).ToUniversalTime()) -UFormat %s))
    $nbf = [int][double]::parse((Get-Date -Date $((Get-Date).ToUniversalTime()) -UFormat %s))

    $CertificateBase64Hash = [System.Convert]::ToBase64String($Cert.GetCertHash())
    # Use the CertificateBase64Hash and replace/strip to match web encoding of base64
    $x5t = $CertificateBase64Hash -replace '\+','-' -replace '/','_' -replace '='

    [hashtable]$header = @{alg = 'RS256'; typ = 'JWT'; x5t = $x5t}
    [hashtable]$payload = @{
        aud = "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token";
        iss = $ClientId; 
        exp = $exp;
        jti = (New-Guid);
        nbt = $nbf;
        sub = $ClientId;
        iat = $issueTime
    }

    $headerjson = $header | ConvertTo-Json -Compress
    $payloadjson = $payload | ConvertTo-Json -Compress
    
    $encodedHeader = ConvertTo-Base64UrlString $headerjson
    $encodedPayload = ConvertTo-Base64UrlString $payloadjson
    $jwt = $encodedHeader + '.' + $encodedPayload
    $toBeSigned = [System.Text.Encoding]::UTF8.GetBytes($jwt)
    $signature = ConvertTo-Base64UrlString $Cert.PrivateKey.SignData($toBeSigned,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $token = $jwt = $jwt + '.' + $signature

    return $token
}

Function Get-TokenWithCert ( [string]$TenantId, [string]$ClientId, [System.Security.Cryptography.X509Certificates.X509Certificate]$Cert, [string]$Scope )
{
    <#
        .LINK
        https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-on-behalf-of-flow
        .LINK
        https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials
        .LINK
        https://stackoverflow.com/questions/50657463/how-to-obtain-value-of-x5t-using-certificate-credentials-for-application-authe

    #>
    Write-Host "Authenticating using a client certificate."

    $uRI = "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("content-type", "application/x-www-form-urlencoded")

    $assertion = New-Jwt -ClientId $ClientId -TenantId $TenantId -Cert $Cert
    
    $body = @{
        client_id                       = $ClientId
        client_assertion_type           = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        scope                           = $Scope
        client_assertion                = $assertion
        grant_type                      = "client_credentials"
    }
    
    $result = Invoke-WebRequest -Method POST -Uri $uRI -Headers $headers -Body $body
    $token =  ($result.content | ConvertFrom-Json).access_token
    return $token
}

Function Get-TokenWithSecret ( [string]$TenantId, [string]$ClientId, [string]$ClientSecret, [string]$Scope )
{
    Write-Host "Authenticating using a client secret."

    $uRI = "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("content-type", "application/x-www-form-urlencoded")

    $body = @{
        client_id       = $ClientId
        scope           = $Scope
        client_secret   = $ClientSecret
        grant_type      = "client_credentials"
    }

    $result = Invoke-WebRequest -Method POST -Uri $uRI -Headers $headers -Body $body
    $token = ($result.Content | ConvertFrom-Json).access_token
    return $token
}

