
<#
    Script:Build_CustomNotifications.ps1

    Author: Robbie Tarnay - Kiandra IT
    Burnt Toast PowerShell Module https://github.com/Windos/BurntToast/releases/download/v0.5.1/BurntToast.zip
    CMLogEntry Function borrowed from Nicolaj Anderson www.sconfigmgr.com
    WMI Permanent Event code borrowed from Ed Wilson https://learn-powershell.net

    .SYNOPSIS

		This script enables monitoring for specific conditions via WMI Event Monitoring and PowerShell Scheduled jobs.
        When a condition is evaluated as true, PowerShell scripts can be executed with the option of displaying a Custom Windows 10 Toast Notification to the end user.

    .PARAMETER EnableRegistryMonitor
        Setting this parameter to $true enables the Registry WMI Event Monitor

	.PARAMETER EnableFolderMonitor
        Setting this parameter to $true enables the Folder WMI Event Monitor

    .PARAMETER EnableUSBMonitoring
		Setting this parameter to $true enables the USB Device WMI Event Monitor

    .PARAMETER EnableFreeDiskSpace Monitor 
		Setting this parameter to $true enables the OS Free Disk Space Check PowerShell Scheduled Job
	
	.EXAMPLE
	 Build_CustomNotifications.ps1 -EnableUSBMonitoring $true -EnableFreeDiskSpace $true	

	
	.NOTES
        Create the following folder names in the root of your Windows 10 Build Scripts Package directory
		- 'PSModules' - Place the BurntToast Module inside it
        - 'Custom Notifications' - Place the LaunchUSBConnection.vbs,USBConnection.ps1 and table.css files inside it
        -  Update the $FolderPath variable on line 95 if you are using the Folder Monitor
        -  Update the $KeyPath variable on line 95 if you are using the Registry Monitor
#>


Param(
[parameter(Mandatory=$false, HelpMessage="Setting parameter to True enables the Registry Change WMI Event Monitor")]
[string]$EnableRegistryMonitor,
[parameter(Mandatory=$false, HelpMessage="Setting parameter to True enables the Folder Change WMI Event Monitor")]
[string]$EnableFolderMonitor,    
[parameter(Mandatory=$false, HelpMessage="Setting parameter to True enables the USB WMI Event Monitor")]
[string]$EnableUSBMonitoring,
[parameter(Mandatory=$false,HelpMessage="Setting parameter to True enables the OS Disk Space Check")]
[string]$EnableFreeDiskSpace

)

#Set Up Task Sequence Logging
 
    # Functions
    function Write-CMLogEntry {
	    param(
		    [parameter(Mandatory=$true, HelpMessage="Value added to the smsts.log file.")]
		    [ValidateNotNullOrEmpty()]
		    [string]$Value,

		    [parameter(Mandatory=$true, HelpMessage="Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
		    [ValidateNotNullOrEmpty()]
            [ValidateSet("1", "2", "3")]
		    [string]$Severity,

		    [parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]
		    [ValidateNotNullOrEmpty()]
		    [string]$FileName = "Custom Toast Notifications.log"
	    )
	    # Determine log file location
        $LogFilePath = Join-Path -Path "$env:windir\CCM\Logs" -ChildPath $FileName

        # Construct time stamp for log entry
        $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))

        # Construct date for log entry
        $Date = (Get-Date -Format "MM-dd-yyyy")

        # Construct context for log entry
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)

        # Construct final log entry
        $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""DynamicApplicationsList"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	
	    # Add value to log file
        try {
	        Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop
        }
        catch [System.Exception] {
            Write-Warning -Message "Unable to append log entry to smsts.log file"
        }
    }
    
#Copy Burnt Toast and required Script files
Copy-Item "$PSScriptRoot\PSModules\BurntToast" -Recurse -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Force
Write-CMLogEntry -Value "Copying Custom Notification Script Files" 
New-Item -ItemType Directory -Path $env:ProgramData -Name 'Custom Notifications' -Force
Copy-Item "$PSScriptRoot\Custom Notifications\*" -Recurse -Destination "$env:ProgramData\Custom Notifications"

function RegistryMonitor  {
$KeyPath = '' 
#Uses POSIX Syntax - Example 'SOFTWARE\\Microsoft\\UEV\\Agent\\Configuration'    
$computer = "$env:COMPUTERNAME"
$filterNS = "root\cimv2"
$wmiNS = "root\subscription"
$query = @"
  SELECT * FROM RegistryKeyChangeEvent WITHIN 10
  WHERE Hive = 'HKEY_LOCAL_MACHINE' AND KeyPath = $KeyPath
"@
$filterName = "RegistryMonitorFilter"
$scriptFileName = "$env:ProgramData\Custom Notifications\LaunchRegistryMonitor.vbs"

$filterPath = Set-WmiInstance -Class __EventFilter `
 -ComputerName $computer -Namespace $wmiNS -Arguments `
  @{name=$filterName; EventNameSpace=$filterNS; QueryLanguage="WQL";
    Query=$query}


$consumerPath = Set-WmiInstance -Class ActiveScriptEventConsumer `
 -ComputerName $computer -Namespace $wmiNS `
 -Arguments @{name="RegistryMonitorConsumer"; ScriptFileName=$scriptFileName;
  ScriptingEngine="VBScript"}

Set-WmiInstance -Class __FilterToConsumerBinding -ComputerName $computer `
  -Namespace $wmiNS -arguments @{Filter=$filterPath; Consumer=$consumerPath} |
  out-null
}

function FolderMonitor  {
$FolderPath = '' 
#Uses POSIX Syntax - Example c:\\\\TestParentFolder\\\\TestChildFolder\   
$computer = "$env:COMPUTERNAME"
$filterNS = "root\cimv2"
$wmiNS = "root\subscription"
$query = @"
  SELECT * FROM __InstanceCreationEvent WITHIN 10 
  WHERE TargetInstance ISA "CIM_DirectoryContainsFile" 
  and TargetInstance.GroupComponent= "Win32_Directory.Name=\"$FolderPath""
"@
$filterName = "FolderMonitorFilter"
$scriptFileName = "$env:ProgramData\Custom Notifications\LaunchFolderMonitor.vbs"

$filterPath = Set-WmiInstance -Class __EventFilter `
 -ComputerName $computer -Namespace $wmiNS -Arguments `
  @{name=$filterName; EventNameSpace=$filterNS; QueryLanguage="WQL";
    Query=$query}


$consumerPath = Set-WmiInstance -Class ActiveScriptEventConsumer `
 -ComputerName $computer -Namespace $wmiNS `
 -Arguments @{name="FolderMonitorConsumer"; ScriptFileName=$scriptFileName;
  ScriptingEngine="VBScript"}

Set-WmiInstance -Class __FilterToConsumerBinding -ComputerName $computer `
  -Namespace $wmiNS -arguments @{Filter=$filterPath; Consumer=$consumerPath} |
  out-null
}

Function USBMonitoring {
$computer = "$env:COMPUTERNAME"
$filterNS = "root\cimv2"
$wmiNS = "root\subscription"
$query = @"
 Select * From Win32_VolumeChangeEvent where EventType = '2'
"@
$filterName = "USBConnectionFilter"
$scriptFileName = "$env:ProgramData\Custom Notifications\LaunchUSBConnection.vbs"

$filterPath = Set-WmiInstance -Class __EventFilter `
 -ComputerName $computer -Namespace $wmiNS -Arguments `
  @{name=$filterName; EventNameSpace=$filterNS; QueryLanguage="WQL";
    Query=$query}


$consumerPath = Set-WmiInstance -Class ActiveScriptEventConsumer `
 -ComputerName $computer -Namespace $wmiNS `
 -Arguments @{name="USBConnectionConsumer"; ScriptFileName=$scriptFileName;
  ScriptingEngine="VBScript"}

Set-WmiInstance -Class __FilterToConsumerBinding -ComputerName $computer `
  -Namespace $wmiNS -arguments @{Filter=$filterPath; Consumer=$consumerPath} |
  out-null

  }


 Function FreeDiskSpace { 

$trigger = New-JobTrigger -Daily -At 11:00AM 
$Option = New-ScheduledJobOption -StartIfOnBattery 
$action = { 
$DiskSpace = Get-WmiObject -Class win32_logicaldisk | Where-Object {$_.DeviceID -eq $env:SystemDrive } 

if ($DiskSpace.FreeSpace/$DiskSpace.Size -lt 0.20 ) {
Import-Module BurntToast
New-BurntToastNotification -Text 'Disk Space is Low' ,'Please Clean Up Unnecessary Files' -AppLogo $env:windir\OEMLogo.bmp

}

if ($DiskSpace.FreeSpace/$DiskSpace.Size -lt 0.10 ) {
New-Item -ItemType Directory -Path "$env:ProgramData\Custom Notifications" -Name Reports
#
$Report = "$env:ProgramData\Custom Notifications\Reports\Used Space Report.html"
$path = "$env:SystemDrive\Users"
##Find out the files greater than equal to below mentioned size
$size = 50MB
##Limit the number of rows
$limit = 100

##script to find out the files based on the above input
$largeSizefiles = Get-ChildItem -path $path -recurse -ErrorAction "SilentlyContinue"  | Where-Object { $_.GetType().Name -eq "FileInfo" } | where-Object {$_.Length -gt $size} | sort-Object -property length -Descending | Select-Object Name, @{Name="SizeInMB";Expression={$_.Length / 1MB}},@{Name="Path";Expression={$_.directory}} -first $limit
$largeSizefiles | ConvertTo-Html -Title 'Used Disk Space Report' -CssUri "$env:windir\Custom Notifications\table.css"| Out-File $Report

Import-Module BurntToast
$Button = New-BTButton -Content 'Report' -Arguments "$Report"
New-BurntToastNotification -Text 'Disk Space is Very Low', 'View Report to see which files are consuming space' -AppLogo $env:windir\OEMLogo.bmp -Button $Button
}
}

$params = @{
Name = "OS Drive Free Space Check"
ScriptBlock = $action
Trigger = $trigger
ScheduledJobOption = $Option

}
#Register the Scheduled Job 
Register-ScheduledJob @params

 }

<#This section of code enables the WMI Event Monitoring or PowerShell Scheduled Jobs
 and logs to the ConfigMgr Logs Directory
#>

#If Registry Monitoring is set to $True
 if ($EnableRegistryMonitor -eq $true) {
 Write-CMLogEntry -Value "Enabling Registry Monitor WMI Event Filter..." -Severity 1
 RegistryMonitor

$WMIEventEnabled = Get-WmiObject -Namespace root\Subscription -Class __EventFilter | Where-Object {$_.Name -eq 'RegistryMonitorFilter'} | Select Name -ExpandProperty Name

If ($WMIEventEnabled -eq 'RegistryMonitorFilter') {

Write-CMLogEntry -Value "Registry Monitor WMI Event Monitor successfully enabled" -Severity 1
 }

 Else { Write-CMLogEntry -Value "Registry Monitor WMI Event Monitor failed to Register" -Severity 3} 

 } 

#If Folder Monitoring is set to $True
 if ($EnableFolderMonitor -eq $true) {
 Write-CMLogEntry -Value "Enabling Folder Monitor WMI Event Filter..." -Severity 1
 FolderMonitor

$WMIEventEnabled = Get-WmiObject -Namespace root\Subscription -Class __EventFilter | Where-Object {$_.Name -eq 'FolderMonitorFilter'} | Select Name -ExpandProperty Name

If ($WMIEventEnabled -eq 'FolderMonitorFilter') {

Write-CMLogEntry -Value "Folder Monitor WMI Event Monitor successfully enabled" -Severity 1
 }

 Else { Write-CMLogEntry -Value "Folder Monitor WMI Event Monitor failed to Register" -Severity 3} 

} 

#If USB Monitoring is set to $True enable the WMI Event Filter

 if ($EnableUSBMonitoring -eq $true) {
 Write-CMLogEntry -Value "Enabling USB Connection WMI Event Filter..." -Severity 1
 USBMonitoring 

$WMIEventEnabled = Get-WmiObject -Namespace root\Subscription -Class __EventFilter | Where-Object {$_.Name -eq 'USBConnectionFilter'} | Select Name -ExpandProperty Name

If ($WMIEventEnabled -eq 'USBConnectionFilter') {

Write-CMLogEntry -Value "USB Connection WMI Event Monitor successfully enabled" -Severity 1
 }

 Else { Write-CMLogEntry -Value "USB Connection WMI Event Monitor failed to Register" -Severity 3} 

 } 

#If Free Disk Space Monitoring is set to $True enable the PowerShell Scheduled Job

 if ($EnableFreeDiskSpace -eq $true) {

    Write-CMLogEntry -Value "Enabling PowerShell Scheduled Job OS Drive Free Space Check..." -Severity 1
 
    FreeDiskSpace 

    $JobEnabled = Get-ScheduledJob -Name 'OS Drive Free Space Check' | Select Enabled -ExpandProperty Enabled

    If ($JobEnabled -eq 'True') {

        Write-CMLogEntry -Value "PowerShell Scheduled Job Disk Drive Free Space Check successfully enabled" -Severity 1

    }

    Else {Write-CMLogEntry -Value "Warning - PowerShell Scheduled Job not successfully enabled" -Severity 3}
 
 }

 