# CREATED BY JIM DAVIS (jimdavis@microsoft.com)
workflow ShutdownController
{
    Param(
        [Parameter(Mandatory=$true)][string]$AutomationAccountName,
        [Parameter(Mandatory=$true)][string]$AAResourceGroupName,
        [Parameter(Mandatory=$true)][Int32]$MaxTiers,
        [Parameter(Mandatory=$false)][string]$TagName = "autoShutdown",
        [Parameter(Mandatory=$false)][bool]$ExcludeWeekends = $false,
        [Parameter(Mandatory=$false)][string]$ConnectionName = "AzureRunAsConnection",
        [Parameter(Mandatory=$false)][string]$ChildRunbookName = "StopAppTier"
    )

    Write-Output "Parameters:"
    Write-Output "AutomationAccountName == $($AutomationAccountName)"
    Write-Output "AAResourceGroupName == $($AAResourceGroupName)"
    Write-Output "MaxTiers == $($MaxTiers)"
    Write-Output "TagName == $($TagName)"
    Write-Output "ExcludeWeekends == $($ExcludeWeekends)"
    Write-Output "ConnectionName == $($ConnectionName)"
    Write-Output "ChildRunBookName == $($ChildRunBookName)"
    
    if ($ExcludeWeekends)
    {
        $d = (Get-Date).DayOfWeek
        if(($d -eq "Saturday") -or ($d -eq "Sunday"))
        {
            Write-Output "Exiting without taking action since today is a weekend."
            Exit
        }
    }    

    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    $result = Select-AzureRmSubscription -SubscriptionId $servicePrincipalConnection.SubscriptionId
    
    Write-Output "Using subsciption $($servicePrincipalConnection.SubscriptionId)"

    Write-Output "Stopping of application tiers is serialized."

    # set iterator to 0 to skip shutting down tier 0.  Setting iterator to -1 will ensure all tiers shutdown.
    for ($i = $MaxTiers; $i -gt 0; $i--)
    {
        # GET COUNT OF ITEMS IN TIER AND ONLY CALL CHILD RUNBOOK WHEN ITEMS ARE GREATER THAN 0
        [int]$count = 0

        $o = $null
        $o = Get-AzureRmVmss | where {$_.Tags[$TagName] -eq $i}
        Write-Output "There are $($o.count) virtual machine scale sets for tier $($i)."

        if (($null -ne $o) -and ($o.count -gt 0))
        {
            $count = $o.count
        }

        $o = $null
        $o = Get-AzureRmVm | Where-Object {$_.Tags[$TagName] -eq $i}

        if (($null -ne $o) -and ($o.count -gt 0))
        {
            $count = $count + $o.count
        }
        
        Write-Output "Application tier $($i) has $($count) resources to stop."

        if ($count -gt 0)
        {           
            try
            {
                Write-Output "Stopping application tier $($i)."
                $params = @{"Tier"=$i; "TagName"=$TagName; "ConnectionName"=$ConnectionName}
                $result = Start-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Name $ChildRunbookName -ResourceGroupName $AAResourceGroupName -Parameters $params -Wait -ErrorAction SilentlyContinue
                Write-Output $result
                Write-Output "Application tier $($i) stopped."
            }
            catch 
            {
                Write-Output $_.Exception
            }
        }
        else
        {
            "The combined count is $($count) so no job will be invoked for tier $($i)."
        }
    }   

    Write-Output "Shutdown Controller completed."
}