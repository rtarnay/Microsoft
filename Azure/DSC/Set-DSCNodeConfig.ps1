
#Applies a DSC COnfig to a DSC Node 

Function Set-DSCNodeConfig {

#Set DSC Configuration on VM 


param (

[parameter(Mandatory=$true)]
[string]$DSCConfigName,
[parameter(Mandatory=$true)]
[string]$DSCNode


)

$DSCAutomationAccountName = "TARNAYLAB-DEVOPS"
$DSCResourceGroupName = "Azure_Automation"

$nodeId = (Get-AzureRmAutomationDscNode -AutomationAccountName $DSCAutomationAccountName -ResourceGroupName $DSCResourceGroupName -Name $DSCNode).Id

$nodeParams = @{
    NodeConfigurationName = "$DSCConfigname.$DSCNode"
    ResourceGroupName = "$DSCResourceGroupName"
    Id = $nodeId
    AutomationAccountName = "$DSCAutomationAccountName"
    Force = $true
}

Set-AzureRmAutomationDscNode @nodeParams

} 