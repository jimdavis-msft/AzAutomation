# CREATED BY JIM DAVIS (jimdavis@microsoft.com)
workflow StartupController
{
    Param(
        [Parameter(Mandatory=$true)][string]$AutomationAccountName,
        [Parameter(Mandatory=$true)][string]$AAResourceGroupName,
        [Parameter(Mandatory=$true)][Int32]$MaxTiers,
        [Parameter(Mandatory=$false)][string]$TagName = "autoStart",
        [Parameter(Mandatory=$false)][bool]$ExcludeWeekends = $false,
        [Parameter(Mandatory=$false)][string]$ConnectionName = "AzureRunAsConnection",
        [Parameter(Mandatory=$false)][string]$ChildRunbookName = "StartAppTier"
    )

    Write-Output "Parameters:"
    Write-Output "AutomationAccountName == $($AutomationAccountName)"
    Write-Output "AAResourceGroupName == $($ResourceGroupName)"
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
        $servicePrincipalConnection=Get-AutomationConnection -Name $ConnectionName         

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

    Write-Output "Start-up for each application tier is serialized."

    # iterator varialbe i set to 1 intentionally to skip tier 0.  Normal value would be 0.
    for ($i=1; $i -lt $MaxTiers + 1; $i++)
    {
        # GET COUNT OF ITEMS IN TIER AND ONLY CALL CHILD RUNBOOK WHEN ITEMS ARE GREATER THAN 0
        [int]$count = 0

        $o = Get-AzureRmResource -TagName $TagName -TagValue $i | where {$_.ResourceType -like "Microsoft.Compute/virtualMachineScaleSets"}
        #Write-Output "There are $($o.count) virtual machine scale sets for tier $($i)."
        if (($null -ne $o) -and ($o.count -gt 0))
        {
            $count = $count + $o.count
        }

        $o = Get-AzureRmResource -TagName $TagName -TagValue $i | where {$_.ResourceType -like "Microsoft.Compute/virtualMachines"}
        #Write-Output "There are $($o.count) virtual machines for tier $($i)."

        if (($null -ne $o) -and ($o.count -gt 0))
        {
            $count = $count + $o.count
        }
        
        Write-Output "Application tier $($i) has $($count) resources to start."

        if ($count -gt 0)
        {
            try
            {
                Write-Output "Starting application tier $($i)."
                $params = @{"Tier"=$i; "TagName"=$TagName; "ConnectionName"=$ConnectionName}
                $result = Start-AzureRmAutomationRunbook -AutomationAccountName $AutomationAccountName -Name $ChildRunbookName -ResourceGroupName $AAResourceGroupName -Parameters $params -Wait -ErrorAction SilentlyContinue
                Write-Output "Application tier $($i) started."
            }
            catch {}
        }
    }   

    Write-Output "Startup Controller completed."
}