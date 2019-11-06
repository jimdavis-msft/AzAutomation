param(
    [Parameter (Mandatory=$false)][object] $WebhookData
)

function Scale-Out([string] $VMScaleSetName, [string]$ResourceGroupName){
    Write-Output "Scale-Out operation completed."
}

function Scale-In([string]$VMScaleSetName, [string] $ResourceGroupName){
    Write-Output "Scale-In operation completed."
}


#####################################################
# BEGIN MAIN SCRIPT PROCESSING
#####################################################

Write-Output "Starting autoScaleOperation."
$subscriptionId = $null
$resourceGroupName = $null
$vmssName = $null
$operationType = $null
$vmssName = $null
$targetCapacity = $null

if ($WebhookData)
{
    try{
        # Collect properties of WebhookData
        $WebhookName     =     $WebhookData.WebhookName
        $WebhookHeaders  =     $WebhookData.RequestHeader
        $WebhookBody     =     $WebhookData.RequestBody

        # Collect individual headers. Input converted from JSON.
        $Input = (ConvertFrom-Json -InputObject $WebhookBody)

        Write-Output "subscriptionId == $($Input.context.subscriptionId)"
        Write-Output "resourceGroupName == $($Input.context.resourceGroupName)"
        Write-Output "resource Name == $($Input.context.resourceName)"

        $operationType = $Input.operation
        $subscriptionId = $Input.context.subscriptionId
        $resourceGroupName = $Input.context.resourceGroupName
        $vmssName = $Input.context.resourceName
        $targetCapacity = $Input.context.newCapacity

        Write-Output -InputObject ('Runbook started from webhook {0} with type {1}.' -f $WebhookName, $Input.operation)
        Write-Output -InputObject ('Scaling from {0} to {1}.' -f $Input.context.oldCapacity, $Input.context.newCapacity)
    }
    catch{}
}
else
{
    Write-Output "Webhookdata object not received."
}

try
{
    # Get the connection "AzurePowerShellRunAsConnection "
    $azureCredential = Get-AutomationPSCredential -Name "azurePSCred"

    if($null -ne $azureCredential)
    {
        Write-Output "Attempting to authenticate as: [$($azureCredential.UserName)]."
        $result = Login-AzureRmAccount -Credential $azureCredential 
        Select-AzureRmSubscription -SubscriptionId $subscriptionId
    }
}
catch {
    Write-Output "Error getting PS Credential"
}

if($operationType.ToLower() -eq "scale out"){
    Write-Output "Scale out operation started."
    Scale-Out $vmssName $resourceGroupName
}

if($operationType.ToLower() -eq "scale in"){
    Write-Output "Scale in operation started."
    Scale-In $vmssName $resourceGroupName
}

Write-Output "Exiting autoScaleOperation."