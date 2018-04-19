
#Following Script Will Register DSC Nodes based on a CSV file 
#Use Azure Get-AzureRmVM | Select Name,ResourceGroupName,Location | Export-Csv $CSVPath and edit as required

$CSVPath = "C:\Temp\AzureVMs.csv"
$DSCVMs = Import-Csv $CSVPath
$DSCAutomationAccountName = "TARNAYLAB-DEVOPS"
$DSCResourceGroupName = "Azure_Automation"


Foreach ($DSCVM in $DSCVMs ) {


Register-AzureRmAutomationDscNode `
-AutomationAccountName $DSCAutomationAccountName `
-AzureVMName $DSCVM.Name `
-ResourceGroupName $DSCResourceGroupName `
-ConfigurationMode ApplyAndAutocorrect `
-AzureVMResourceGroup $DSCVM.ResourceGroupName `
-AzureVMLocation $DSCVM.Location `
-RefreshFrequencyMins 30 -Verbose

}

