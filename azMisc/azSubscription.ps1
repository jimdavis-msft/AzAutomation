# This example iterates over all the available subscriptions for the current user security context and 
# executes a placeholder function.  This might be useful if you have to perform the same function across
# many different subcriptions at the same time.

Function SomeInterestingFunction
{
    Write-Host "Doing some interesting work."
}

if ($null -eq (Get-AzContext))
{
    $context = Connect-AzAccount
}

$subscriptions = Get-AzSubscription

foreach ($_ in $subscriptions)
{
    Write-Host "Setting Subscription target to $($_.Name)"
    Set-AzContext -Subscription $_.Id

    SomeInterestingFunction
}