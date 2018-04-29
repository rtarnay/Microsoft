
$MOFOutputPath = "C:\Temp"

Configuration SCCMPrimarySiteConfiguration

{ 

#Import the xNetorking Module Before 

   Import-DscResource -ModuleName PSDesiredStateConfiguration
   Import-DscResource -ModuleName xNetworking

    node "localhost"
    
    { 

#Install Windows Server PreRequisites 

 @(
'BITS',
'BITS-IIS-Ext',
'BITS-Compact-Server', 
'Web-Server', 
'Web-WebServer', 
'Web-Common-Http', 
'Web-Default-Doc',
'Web-Dir-Browsing',
'Web-Http-Errors',
'Web-Static-Content', 
'Web-Http-Redirect',
'Web-App-Dev',
'Web-Net-Ext',
'Web-Net-Ext45',
'Web-ASP',
'Web-Asp-Net',
'Web-Asp-Net45',
'Web-CGI',
'Web-ISAPI-Ext',
'Web-ISAPI-Filter',
'Web-Health',
'Web-Http-Logging',
'Web-Custom-Logging',
'Web-Log-Libraries',
'Web-Request-Monitor',
'Web-Http-Tracing',
'Web-Performance',
'Web-Stat-Compression',
'Web-Security',
'Web-Filtering',
'Web-Basic-Auth',
'Web-IP-Security',
'Web-Url-Auth',
'Web-Windows-Auth',
'Web-Mgmt-Tools',
'Web-Mgmt-Console',
'Web-Mgmt-Compat',
'Web-Metabase',
'Web-Lgcy-Mgmt-Console',
'Web-Lgcy-Scripting',
'Web-WMI',
'Web-Scripting-Tools',
'Web-Mgmt-Service', 
'RDC').ForEach({

             WindowsFeature $_
             {
                Name = $_
                Ensure = 'Present'
             }
         })


#Set FireWall Rules for Primary Site Server 

xFirewall PSRemoteAndSCCRulesInboundTCP

{

 Name = "PSRemoting and SCCM Inbound Rules TCP"

 Ensure = "Present"

 Direction = "Inbound"

 Description = "PSRemoting and SCCM Inbound Rules TCP"

 Profile = "Domain"

 Protocol = "TCP"

 LocalPort = ("443","1723","8530","8531","445","135","5986")

 Action = "Allow"

 Enabled = "True"

}

xFirewall PSRemoteAndSCCRulesOutboundTCP

{

 Name = "PSRemoting and SCCM Outbound Rules TCP"

 Ensure = "Present"

 DependsOn = "[xFireWall]PSRemoteAndSCCRulesInboundTCP"

 Direction = "Outbound"

 Description = "PSRemoting and SCCM Outbound Rules TCP"

 Profile = "Domain"

 Protocol = "TCP"

 LocalPort = ("443","1723","8530","8531","445","135","5986")

 Action = "Allow"

 Enabled = "True"

}

xFirewall PSRemoteAndSCCRulesInboundUDP

{

 Name = "PSRemoting and SCCM Inbound Rules UDP"

 Ensure = "Present"

 DependsOn = "[xFireWall]PSRemoteAndSCCRulesOutboundTCP"

 Direction = "Inbound"

 Description = "PSRemoting and SCCM Inbound Rules UDP"

 Profile = "Domain"

 Protocol = "UDP"

 LocalPort = ("135")

 Action = "Allow"

 Enabled = "True"

}

xFirewall PSRemoteAndSCCRulesOutboundUDP

{

 Name = "PSRemoting and SCCM Outbound Rules UDP"

 Ensure = "Present"

 DependsOn = "[xFireWall]PSRemoteAndSCCRulesInboundUDP"

 Direction = "Outbound"

 Description = "PSRemoting and SCCM Outbound Rules UDP"

 Profile = "Domain"

 Protocol = "UDP"

 LocalPort = ("135")

 Action = "Allow"

 Enabled = "True"

}

xFirewall PSRemoteAndSCCRulesOutboundTCPEphemeral

{

 Name = "PSRemoting and SCCM Outbound Rules TCP Ephemeral"

 Ensure = "Present"

 DependsOn = "[xFireWall]PSRemoteAndSCCRulesOutboundUDP"

 Direction = "Outbound"

 Description = "PSRemoting and SCCM Outbound Rules TCP Ephemeral"

 Profile = "Domain"

 Protocol = "TCP"

 LocalPort = ("49152-65535")

 Action = "Allow"

 Enabled = "True"

}

xFirewall PSRemoteAndSCCRulesInboundTCPEphemeral

{

 Name = "PSRemoting and SCCM Inbound Rules TCP Ephemeral"

 Ensure = "Present"

 DependsOn = "[xFireWall]PSRemoteAndSCCRulesOutboundUDP"

 Direction = "Inbound"

 Description = "PSRemoting and SCCM Inbound Rules TCP Ephemeral"

 Profile = "Domain"

 Protocol = "TCP"

 LocalPort = ("49152-65535")

 Action = "Allow"

 Enabled = "True"

}
  
 Script InstallNoSMSOnDrive {

GetScript = {

  @{'ExcludeDrive' = (Get-CimInstance -ClassName Win32_LogicalDisk).where({$PSItem.DriveType -eq '3' -and $PSItem.DeviceID -ne 'D:'})}

 }#EndGetScript

 TestScript = {

  $LogicalDisk = (Get-CimInstance -ClassName Win32_LogicalDisk).where({$PSItem.DriveType -eq '3' -and $PSItem.DeviceID -ne 'D:'})

  $DiskCheck = ForEach($Drive in $LogicalDisk){

   $Disk = ($Drive.DeviceID + '\')

   $Output = Test-Path ($Disk + 'NO_SMS_ON_DRIVE.sms')

   If ($Output -eq $false){Return $false}

   }#ForEach

   If($DiskCheck -eq $null){Return $True}

 }#EndTestScript

 SetScript = {

  $LogicalDisk = (Get-CimInstance -ClassName Win32_LogicalDisk).where({$PSItem.DriveType -eq '3' -and $PSItem.DeviceID -ne 'D:'})

  ForEach($Drive in $LogicalDisk){

  $Disk = ($Drive.DeviceID + '\')      

   If(!(Get-Item -Path ($Disk + 'NO_SMS_ON_DRIVE.sms') -ErrorAction SilentlyContinue)){     

   New-Item -Name 'NO_SMS_ON_DRIVE.sms' -Path $Disk -ItemType File  

   }#EndIf

  }#EndForeach

 }#EndSetScript

 DependsOn = "[xFirewall]PSRemoteAndSCCRulesInboundTCPEphemeral"

}#EndScript  


    }
} 


SCCMPrimarySiteConfiguration -OutputPath "$MOFOutputPath\SCCMPrimarySite"

Start-DscConfiguration -Path "$MOFOutputPath\SCCMPrimarySite" -Wait -Verbose -Force 