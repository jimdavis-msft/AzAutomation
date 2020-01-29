vault_name = "testvault"
secret_name = "secret1"

response=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true -s)
access_token=$(echo $response | python -c 'import sys, json; print (json.load(sys.stdin)["access_token"])')
curl https://${vault_name}.vault.azure.net/secrets/${secret_name}?api-version=2016-10-01 -H "Authorization: Bearer ${access_token}"