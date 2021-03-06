param(
    [Parameter (Mandatory=$true)][string] $resourceGroupName
)

$connectionName = "AzureRunAsConnection"
$psCredName = "azurePSCred"
$aaName = ""
$aaResourceGroup = ""

#####################################################
# BEGIN MAIN SCRIPT PROCESSING
#####################################################
try
{
    # Get the connection "AzurePowerShellRunAsConnection "
    $azureCredential = Get-AutomationPSCredential -Name $psCredName
    Write-Output Get-AzContext

    if($null -ne $azureCredential)
    {
        Write-Output "Attempting to authenticate as: [$($azureCredential.UserName)]."
        Connect-AzAccount -Credential $azureCredential
    }
    else
    {
        Write-Output "Azure credential is null."
    }
}
catch {
    Write-Output "Error getting PS Credential"
}

# CHECK IF RESOURCE GROUP EXISTS ALREADY
$result = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $result){
    Write-Output "Resource Group does not exist.  Exiting."
}
else{
    Write-Output "Resource Group exists."
}

# GET OUR TARGET RESOURCE GROUP AS AN OBJECT
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

Remove-AzResourceGroup -Id $rg.ResourceId -Force

Write-Output "Resource Group removed successfully."

