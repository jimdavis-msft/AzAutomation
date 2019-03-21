Overview

This solution enables the creation of data disks from a snapshot and then attaches the data disks to virtual machine scale set VM instances as part of a scale out operations.  It also supports removing unattached disks which are no longer used when a scale-in operation completes.  

The autoScale.ps1 script should be run as a PowerShell script in an Azure Automation Account with a webhook.  The VM scale set autoscale definition should have a Notify property that uses the webhook url to invoke the autoScale.ps1 script and pass the scale operation information as part of the webhookdata object.

The prestageDataDisks.ps1 can be used in conjunction with the autoScale.ps1 script to pre-stage the data disks to reduce the overall time required to complete a scale-out operation.

