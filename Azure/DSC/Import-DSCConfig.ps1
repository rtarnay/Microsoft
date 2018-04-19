
#Import and Compile DSC Config


Function Import-AzureDSCConfig  { 

param (

[string]$DSCAutomationAccountName = "TARNAYLAB-DEVOPS" , 
[string]$DSCResourceGroupName = "Azure_Automation" ,
[parameter(Mandatory=$true)]
[string]$DSCConfigPath,
[parameter(Mandatory=$true)]
[string]$DSCConfigName


)

# Import DSC Config 

$params = @{
    AutomationAccountName = "$DSCAutomationAccountName"
    ResourceGroupName = "$DSCResourceGroupName"
    SourcePath = "$DSCConfigPath"
    Published = $true
    Force = $true
}

$null = Import-AzureRmAutomationDscConfiguration @params


#Compile the Configuration to build the MOF file 


$compParams = @{
    AutomationAccountName = "$DSCAutomationAccountName"
    ResourceGroupName = "$DSCResourceGroupName"
    ConfigurationName = "$DSCConfigName"
}

$CompilationJob = Start-AzureRmAutomationDscCompilationJob @compParams

## Wait for the DSC compilation process
while($CompilationJob.EndTime -eq $null -and $CompilationJob.Exception -eq $null)
{
    $CompilationJob = $CompilationJob | Get-AzureRmAutomationDscCompilationJob
    Start-Sleep -Seconds 3
}

}