<#
##########################################################################
# Created on:   15/01/2018
# Created by:   Robbie Tarnay - Kiandra IT
#-------------------------------------------------------------------------
# Script Name: Create-OSDTaskSequence.ps1
##########################################################################

	.SYNOPSIS
#Tested with ConfigMgr Technical Preview 1712 

This script will perform the following:

#Creates a new Windows OSD Task Sequence
#Creates
#Recreates any Task Sequence steps,groups or conditions if they have been deleted/modified
#Automatically adds any new Driver Packs and Tier 1 Applications to Task Sequencef

 

	
	.NOTES

#Ensure that your packages that contain task sequence build scripts have been created before running this script.

#Assign all Tier 1 Applications with Category 'Tier 1'

#DriverPacks should be created with model name only ie Do not include Vendor in Driver Pack Name -  Example : Latitude 7480. Add 'Windows 10' to driverpack description. 

#This script can be used as template but will most lilely require updates to suit your Task Sequence requirements  

#Curently no PowerShell support for MDT Integration 

#Doesnt appear to be full PowerShell support for USMT Task Sequence Steps - request and release state store cmdlets only
		
#>


$ErrorActionPreference = 'SilentlyContinue'

#Import ConfigMgr PowerShell Module 

Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")$SiteCode = Get-PSDrive -PSProvider CMSITESet-Location "$($SiteCode.Name):\"



#Client Specific Settings 
$DJuserpassword = Get-Credential
$TaskSequenceName = 'Test Deploy 4 - Windows 10 Enterprise'
$ConfigMgrServer = '' 
$DJAccount = ''
$Domain = ''
$OU = ''
$UserName = ''
$OrganisationName = ''
$ImagePackage = Get-CMOperatingSystemImage -Name 'Windows 10*'
$BuildScriptsPkg = Get-CMPackage -Name '*Build Scripts*'
$USMTPkg = Get-CMPackage -Name '*User State Migration*'
$CMClientPackage = Get-CMPackage -Name "Configuration Manager Client Package"
$OSDLogsPath = ""

#Set PowerShell Script Names Referenced in Task Sequence for run Command Line Task Sequence Step

$SetBitlockerVar =  'Configure_BitlockerVariable.ps1' #Checks whether Bitlocker is enabled and sets IsBDE Task Sequence Variable 
$BDEAES256 = 'Configure_BitlockerAES256.ps1' #Sets AES 256 Encryptiom before preprovision Bitlocker Step
$SetOSDCompName = 'Configure_OSDComputerName.ps1' #Sets the OSD ComputerName Variable
$WindowsFeatures ='Configure_WindowsFeatures.ps1' # Adds and Removes Windows Features
$ClientConfigScript = 'Configure_ClientSettings.ps1' #Customises the Windows Image with client specific settings
$UniversalApps = 'Configure_UniversalApplications.ps1'#Removes unused Unoversal Applications
$CopyBuildLogs = 'Build_CopyOSDLogs.ps1' #Copies Logs at end of the build - replaces SLShare MDT Rules Property with MDT Integration 



#Set Common Task Sequence Conditional Variables Here 

$WinPETrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'True'
$WinPEFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'False'

$UEFITrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'True'
$UEFIFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'False'

$BuildTypeRefreshVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'RefreshComputer'
$BuildTypeReplaceVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'ReplaceComputer'

$BdeTrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'True'
$BdeFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'False'



#Create a new Task Sequence if it doesnt exist 

$TS = Get-CMTaskSequence -Name $TaskSequenceName

if (!$TS) { 

Write-Host "Creating New Task Sequence.." -ForegroundColor Yellow 
 
$NewTS = New-CMTaskSequence -CustomTaskSequence -Name "$TaskSequenceName" -Description "A Custom Windows 10 Task Sequence"

$TS = Get-CMTaskSequence -Name $TaskSequenceName

}


#Create the Task Sequence Groups 

Write-Host "Creating Task Sequence Groups.." -ForegroundColor Yellow 

$TSGroupNames = @(
'Preparation',`
'Capture User Data',`
'Install Operating System',`
'Apply Device Drivers',`
'Setup OperatingSystem',`
'Install Tier 1 Applications',`
'Apply Client Config',`
'Restore User Data',`
'Run Windows Activation',`
'Windows Updates',`
'Finalise'
)


$i = -1
foreach ($TSGroupName in $TSGroupNames) 

{

$i++

$TSGroup = Get-CMTaskSequenceGroup -TaskSequenceName $TaskSequenceName -StepName $TSGroupName

If (!$TSGroup) {


$NewTSGroup = New-CMTaskSequenceGroup -Name $TSGroupName

Write-Host -ForegroundColor Green "Creating Group $TSGroupName"
Add-CMTaskSequenceStep -InsertStepStartIndex $i -TaskSequenceName $TS.Name -Step $NewTSGroup


}

}

#Get Task Sequence Groups for configuring task sequence steps 

$Preparation = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Preparation"
$USMTCapture = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Capture User Data"
$InstallOS = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Install Operating System"
$Drivers = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Apply Device Drivers"
$SetupOS = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Setup OperatingSystem"
$Tier1Apps = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Install Tier 1 Applications"
$ClientCustomisation = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Apply Client Config"
$USMTRestore = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Restore User Data"
$Activation = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Run Windows Activation"
$Updates = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Windows Updates"
$Finalise = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "Finalise"




<###############################################################################

Preparation Group 
 
################################################################################>

Write-Host "Creating Preparation TS Steps.." -ForegroundColor Yellow 

$PreparationSteps = @(
"Set OSDBuildVersion",`
"Set SMSTSDownloadRetryCount",`
"Set SMSTSDownloadRetryDelay",`
"Set SMSTSPostAction",`
"Set SLShare"
) 

$PreparationTable = @{

TSVariable1 = New-CMTaskSequenceStepSetVariable -Name "Set OSDBuildVersion" -TaskSequenceVariable 'OSDBuildVersion' -TaskSequenceVariableValue '1.0'

TSVariable2 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSDownloadRetryCount" -TaskSequenceVariable 'SMSTSDownloadRetryCount' -TaskSequenceVariableValue '5'

TSVariable3 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSDownloadRetryDelay" -TaskSequenceVariable 'SMSTSDownloadRetryDelay' -TaskSequenceVariableValue '15' 

TSVariable4 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSPostAction" -TaskSequenceVariable 'SMSTSPostAction' -TaskSequenceVariableValue 'shutdown.exe -r -t 00' 

TSVariable5 = New-CMTaskSequenceStepSetVariable -Name "Set SLShare" -TaskSequenceVariable 'SLShare' -TaskSequenceVariableValue $OSDLogsPath 

}

$i = -1
$a = 0

foreach ($Step in $PreparationSteps ) {

$a++
$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if(!$StepName) { 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $PreparationTable['TSVariable'+"$a"] -InsertStepStartIndex $i 

}


Else { 

switch ($Step) 
{
    "Set OSDBuildVersion" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName "Set OSDBuildVersion" -TaskSequenceVariable 'OSDBuildVersion' -TaskSequenceVariableValue '1.0' }
    "Set SMSTSDownloadRetryCount" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName "Set SMSTSDownloadRetryCount" -TaskSequenceVariable 'SMSTSDownloadRetryCount' -TaskSequenceVariableValue '5'  }
    "Set SMSTSDownloadRetryDelay" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName "Set SMSTSDownloadRetryDelay" -TaskSequenceVariable 'SMSTSDownloadRetryDelay' -TaskSequenceVariableValue '15' }
    "Set SMSTSPostAction" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName "Set SMSTSPostAction" -TaskSequenceVariable 'SMSTSPostAction' -TaskSequenceVariableValue 'shutdown.exe -r -t 00' }
    "Set SLShare" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName "Set SLShare" -TaskSequenceVariable 'SLShare' -TaskSequenceVariableValue '\\cm02\OSDLogs$'  }
  }


    }

  }


<###############################################################################

Disk Partitioning - WinPE 
 
################################################################################>


$GetWinPEGroup = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "WinPE" 

if (!$GetWinPEGroup)
{

# Create WinPE group
$WinPE = New-CMTaskSequenceGroup -Name "WinPE"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $WinPE -InsertStepStartIndex 5 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'WinPE' -AddCondition ($WinPETrue,$UEFITrue)
}

Else { 
    
    $GetWinPECondition = $GetWinPEGroup.Condition.Operands | Where-Object {$_.Variable -eq '_SMSTSInWinPE' -and $_.Value -eq 'True' }

    if (!$GetWinPECondition) {

    Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'WinPE' -RemoveConditionVariable 

    Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'WinPE' -AddCondition ($WinPETrue,$UEFITrue)

    }
}


#Create Format and Partition Disk Step in WinPE Group 
$PartSetting1 = New-CMTSPartitionSetting -Name 'Windows Recovery' -PartitionRecovery -Size 300 -SizeUnit MB
$PartSetting2 = New-CMTSPartitionSetting -Name 'EFI' -PartitionEfi -Size 500 -SizeUnit MB 
$PartSetting3 = New-CMTSPartitionSetting -Name 'MSR' -PartitionMsr -Size 128 -SizeUnit MB 
$PartSetting4 = New-CMTSPartitionSetting -Name 'OSDisk' -PartitionPrimary -Size 100 -SizeUnit Percent -EnableQuickFormat $true -PartitionFileSystem Ntfs

#Get Partition Disk Step 

$GetPartitionDisk = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Partition Disk - Partitionless Machine - WinPE'

If (!$GetPartitionDisk) {

$PartitionDisk = New-CMTaskSequenceStepPartitionDisk -DiskType Gpt -DiskNumber 0 -IsBootDisk $True -Name 'Partition Disk - Partitionless Machine - WinPE' -PartitionSetting ($PartSetting1,$PartSetting2,$PartSetting3,$PartSetting4)
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $WinPE.Name -AddStep $PartitionDisk -InsertStepStartIndex 0

}


# Add Restart Step

$GetRestartComp = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Restart in WinPE' 

if(!$GetRestartComp) {
 
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart in WinPE' -RunAfterRestart WinPE -MessageTimeout 10
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $WinPE.Name -AddStep $RestartComp -InsertStepStartIndex 1

}

Else {

    Set-CMTaskSequenceStepReboot -TaskSequenceName $TS.Name -StepName 'Restart in WinPE' -RunAfterRestart WinPE -MessageTimeout 10
    
}
 
 #

 #Set Bitlocker Variable

$GetBitlockerVar = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Set BitlockerVariable'

If (!$GetBitlockerVar) {

$SetBitlockerVar = New-CMTaskSequenceStepRunCommandLine -StepName "Set BitlockerVariable" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$SetBitlockerVar" -PackageId $BuildScriptsPkg.PackageID
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $SetBitlockerVar -InsertStepStartIndex 6

}

Else {
      Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set BitlockerVariable" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$SetBitlockerVar" -PackageId $BuildScriptsPkg.PackageID  

 }

 #>

<###############################################################################

Capture User Data Group
 
################################################################################>

Write-Host "Creating USMT Capture TS Steps.." -ForegroundColor Yellow 

$USMTPkgID = $USMTPkg.PackageID
$CaptureUserData = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data'


$USMTCaptureCondition = $CaptureUserData.Condition.Operands | Where-Object {$_.Variable -eq 'BuildType' -and $_.Value -eq 'RefreshComputer' }

If(!$USMTCaptureCondition) {
 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data' -RemoveConditionVariable
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data' -AddCondition $BuildTypeRefreshVar

}



$USMTCaptureSteps = @(
"Disable Bitlocker",`
"USMT - Set Additional Capture Options - Windows",`
"USMT - Set OSDStateStore"

) 

$USMTCaptureTable = @{

USMTStep1 = New-CMTaskSequenceStepDisableBitLocker -Name 'Disable Bitlocker' -Condition $BdeTrue

USMTStep2 = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Capture Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalCaptureOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*" 

USMTStep3 = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set OSDStateStore' -TaskSequenceVariable 'OSDStateStore' -TaskSequenceVariableValue 'C:\OSDStateStore'


}

$i = -1
$a = 0

foreach ($Step in $USMTCaptureSteps ) {

$a++
$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if(!$StepName) { 


Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTCapture.Name -AddStep $USMTCaptureTable['USMTStep'+"$a"] -InsertStepStartIndex $i 

}

Else {

switch ($Step) 

{ 

 "Disable Bitlocker" { $DisableBitlocker = Get-CMTaskSequenceStepDisableBitLocker -TaskSequenceName $TS.Name -StepName "Disable Bitlocker"
 $DisableBitlocker = $DisableBitlocker.Condition.Operands | Where-Object {$_.Variable -eq 'IsBde' -and $_.Value -eq 'True' }

if (!$DisableBitlocker) { 

Set-CMTaskSequenceStepDisableBitLocker -TaskSequenceName $TS.Name -StepName "Disable Bitlocker" -ClearConditions 

Set-CMTaskSequenceStepDisableBitLocker -CurrentDrive -TaskSequenceName $TS.Name -StepName "Disable Bitlocker" -AddCondition $BdeTrue

} }

"USMT - Set Additional Capture Options - Windows" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName 'USMT - Set Additional Capture Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalCaptureOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*" }
"USMT - Set OSDStateStore" { Set-CMTaskSequenceStepSetVariable -TaskSequenceName $TS.Name -StepName 'USMT - Set OSDStateStore' -TaskSequenceVariable 'OSDStateStore' -TaskSequenceVariableValue 'C:\OSDStateStore'}

}

}


}



<###############################################################################

Install Operating System
 
################################################################################>

Write-Host "Creating Install OS TS Steps.." -ForegroundColor Yellow 

$TimeZone = Get-TimeZone

$GetRestartComp = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Restart WinPE' 

if(!$GetRestartComp) {

# Add Restart Step 
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart WinPE' -RunAfterRestart WinPE -MessageTimeout 10 -Condition $WinPEFalse
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $InstallOS.Name -AddStep $RestartComp -InsertStepStartIndex 0

}

Else {

$GetRestartComp = $GetRestartComp.Condition.Operands | Where-Object { $_.Variable -eq '_SMSTSInWinPE' -and $_.Value -eq 'False' }
   
   if (!$GetRestartComp) { 
    
    Set-CMTaskSequenceStepReboot -Name 'Restart WinPE' -RunAfterRestart WinPE -MessageTimeout 10 -RemoveConditionVariable
    Set-CMTaskSequenceStepReboot -Name 'Restart WinPE' -RunAfterRestart WinPE -MessageTimeout 10 -AddCondition $WinPEFalse

    }
}
 


$InstallOSSteps = @(
"Set AES256 Encryption",`
"Apply Operating System Image",`
"Set OSDComputerName",`
"Apply Windows Settings",`
"Join $OrganisationName Domain"
) 


$InstallOSTable = @{

InstallOSStep1 = New-CMTaskSequenceStepRunCommandLine -StepName "Set AES256 Encryption " -CommandLine "powershell.exe -executionpolicy Bypass -file ./$BDEAES256" -PackageId $BuildScriptsPkg.PackageID

InstallOSStep2 = New-CMTaskSequenceStepApplyOperatingSystem -ImagePackage $ImagePackage -Destination SpecificLogicalDriverLetter -DestinationDriveLetter 'C:' -ImagePackageIndex 1 -Name 'Apply Operating System Image' 

InstallOSStep3 = New-CMTaskSequenceStepRunCommandLine -StepName "Set OSDComputerName" -CommandLine "powershell.exe -executionpolicy Bypass -file ./$SetOSDCompName" -PackageId $BuildScriptsPkg.PackageID

InstallOSStep4 = New-CMTSStepApplyWindowsSetting -Name 'Apply Windows Settings' -UserName $UserName  -OrganizationName $OrganisationName -ServerLicensing NotSpecified -TimeZone $TimeZone

InstallOSStep5 = New-CMTaskSequenceStepApplyNetworkSetting -Name "Join $OrganisationName Domain" -DomainName $Domain -DomainOU $OU -UserName $DJAccount -UserPassword $DJuserpassword.Password 

}

$i = 0


foreach ($Step in $InstallOSSteps ) {


$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if(!$StepName) { 

Write-Host -ForegroundColor Green "Creating Install OS Step: $Step"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $InstallOS.Name -AddStep $InstallOSTable['InstallOSStep'+"$i"] -InsertStepStartIndex $i 

}

Else {
switch ($Step) {

"Set AES256 Encryption"  { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set AES256 Encryption" -CommandLine "powershell.exe -executionpolicy Bypass -file ./$BDEAES256" -PackageId $BuildScriptsPkg.PackageID }
"Apply Operating System Image" { Set-CMTaskSequenceStepApplyOperatingSystem -TaskSequenceName $Ts.Name -ImagePackage $ImagePackage -Destination SpecificLogicalDriverLetter -DestinationDriveLetter 'C:' -ImagePackageIndex 1 -Name 'Apply Operating System Image' }
"Set OSDComputerName" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set OSDComputerName" -CommandLine "powershell.exe -executionpolicy Bypass -file ./$SetOSDCompName" -PackageId $BuildScriptsPkg.PackageID}
"Apply Windows Settings" { Set-CMTSStepApplyWindowsSetting -TaskSequenceName $TS.Name -Name 'Apply Windows Settings' -UserName $UserName  -OrganizationName $OrganisationName -ServerLicensing NotSpecified -TimeZone $TimeZone}
"Join $OrganisationName Domain" { Set-CMTaskSequenceStepApplyNetworkSetting -TaskSequenceName $TS.Name -Name 'Apply Network Settings' -DomainName $Domain -DomainOU $OU -UserName $DJAccount -UserPassword $DJuserpassword.Password}


}

}

}


#Add Bitlocker Preprovisioning Step - for some reason this step didnt work in the above function 

$PreProvBde = Get-CMTaskSequenceStepOfflineEnableBitLocker -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker"
if (!$PreProvBde ) 
{

$SetPreProvBDE = New-CMTaskSequenceStepOfflineEnableBitLocker -Drive 'C:' -EnableSkipWhenTpmInvalid $true -StepName 'PreProvision Bitlocker' -Condition $BdeFalse
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $InstallOS.Name -AddStep $SetPreProvBDE -InsertStepStartIndex '2' 

}

Else { Set-CMTaskSequenceStepOfflineEnableBitLocker -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker" -Drive 'C:' -EnableSkipWhenTpmInvalid $true

$GetPreProvBde = Get-CMTaskSequenceStepOfflineEnableBitLocker -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker"
$GetPreProvBde = $GetPreProvBde.Condition.Operands | Where-Object {$_.Variable -eq 'ISBDe' -and $_.Value -eq 'False' }

if (!$GetPreProvBde) {
Set-CMTaskSequenceStepOfflineEnableBitLocker -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker" -RemoveConditionVariable
Set-CMTaskSequenceStepOfflineEnableBitLocker -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker"  -AddCondition $BdeFalse 

}
}


<###############################################################################

Apply Device Drivers 
 
################################################################################>

Write-Host "Creating Apply Drivers TS Steps.." -ForegroundColor Yellow 

$DriverPacks = Get-CMDriverPackage | Where-Object {$_.Description -like '*Windows 10*' } | Select Name -ExpandProperty Name

ForEach ($DriverPack in $DriverPacks ) { 

 
 $DriverPackName = (Get-CMDriverPackage -Name $DriverPack).Name
 $DriverPackId = (Get-CMDriverPackage -Name $DriverPack).PackageId

 $GetDriverPack = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $DriverPackName

 if (!$GetDriverPack)
 {

 Write-Host -ForegroundColor Green "Creating Install $DriverPackName Step"
 $WmiQuery = New-CMTaskSequenceStepConditionQueryWMI -Query "Select * from win32_computersystem WHERE model like '%$DriverPackName%'" 

 $ApplyDriverPack = New-CMTaskSequenceStepApplyDriverPackage -Name $DriverPackName -PackageId $DriverPackId -Condition $WmiQuery

 Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Drivers.Name -AddStep $ApplyDriverPack
 
 }
  
  Else { 

  $WmiQuery = New-CMTaskSequenceStepConditionQueryWMI -Query "Select * from win32_computersystem WHERE model like '%$DriverPackName%'" 

  Set-CMTaskSequenceStepApplyDriverPackage -TaskSequenceName $TS.Name -StepName $DriverPackName -PackageId $DriverPackId 

  $GetDriverPackCondition = Get-CMTaskSequenceStepApplyDriverPackage -TaskSequenceName $TS.Name -StepName $DriverPack | Where-Object {$_.Condition -match "'%$DriverPackName%'" } 
  
  if (!$GetDriverPackCondition) {
  
  Set-CMTaskSequenceStepApplyDriverPackage -TaskSequenceName $TS.Name -StepName $DriverPackName -RemoveConditionQueryWmi 

  Set-CMTaskSequenceStepApplyDriverPackage -TaskSequenceName $TS.Name -StepName $DriverPackName -AddCondition $WmiQuery 
  
  }

  }

} 



<###############################################################################

Setup Operating System  
 
################################################################################>

Write-Host "Creating Setup OS TS Steps.." -ForegroundColor Yellow 


$GetSetupOSStep =  Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Setup Windows and ConfigMgr'

if (!$GetSetupOSStep)
{

$SetupWindowsCfgMgr = New-CMTaskSequenceStepSetupWindowsAndConfigMgr -PackageId $CMClientPackage.PackageID -StepName 'Setup Windows and ConfigMgr' -InstallationProperty "SMSCACHESIZE=20480 SMSMP=$ConfigMgrServer FSP=$ConfigMgrServer"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $SetupOS.Name -AddStep $SetupWindowsCfgMgr 

}

Else { 
      
      Set-CMTaskSequenceStepSetupWindowsAndConfigMgr -TaskSequenceName $TS.Name -StepName 'Setup Windows and ConfigMgr' -PackageId $CMClientPackage.PackageID -InstallationProperty "SMSCACHESIZE=20480 SMSMP=$ConfigMgrServer FSP=$ConfigMgrServer"
        
}

<###############################################################################

Install Applications  
 
################################################################################>

Write-Host "Creating Install Tier 1 Apps.." -ForegroundColor Yellow 

$GetTier1Apps = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Install Tier 1 Apps'
$Applications = Get-CMApplication | Where-Object {$_.LocalizedCategoryInstanceNames -eq 'Tier 1'}

#If Application Group Already Exists, add any new Tier 1 Apps 

if ($GetTier1Apps)
{

 Set-CMTaskSequenceStepInstallApplication -TaskSequenceName $TS.Name -StepName 'Install Tier 1 Apps' -Application $Applications

 }

Else {  


$Apps = New-CMTaskSequenceStepInstallApplication -Name 'Install Tier 1 Apps' -Application $Applications -ContinueOnInstallError 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Tier1Apps.Name -AddStep $Apps

}


<###############################################################################

Apply Client Customisations 
 
################################################################################>

Write-Host "Creating Apply Client Customistations TS Steps.." -ForegroundColor Yellow 

$ClientCustTable = @{

CommandLine1 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Windows Features" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$WindowsFeatures" -PackageId $BuildScriptsPkg.PackageID 

CommandLine2 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Universal Apps" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$UniversalApps" -PackageId $BuildScriptsPkg.PackageID 

CommandLine3 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Client Settings" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$ClientConfigScript" -PackageId $BuildScriptsPkg.PackageID 

}


$ClientConfigSteps = @(
"Configure Windows Features",`
"Configure Universal Apps",`
"Configure Client Settings")

$i = 0 

foreach ($Step in $ClientConfigSteps) { 

$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if (!$StepName) 

{ 
Write-Host "Creating Client Customistaion Group TS Step: $Step" -ForegroundColor Green 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $ClientCustomisation.Name -InsertStepStartIndex $i -AddStep $ClientCustTable['CommandLine'+"$i"]   
 
 }

 Else { 

 switch ($Step) {

"Configure Windows Features"{Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Windows Features" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$WindowsFeatures" -PackageId $BuildScriptsPkg.PackageID}
"Configure Universal Apps"{Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Universal Apps" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$UniversalApps" -PackageId $BuildScriptsPkg.PackageID}
"Configure Client Settings" {Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Client Settings" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$ClientConfigScript" -PackageId $BuildScriptsPkg.PackageID }

 }

 }

}


$GetRestartComp = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $ClientCustomisation.Name | Where-Object {$_.Steps -match 'Restart Computer' }

if(!$GetRestartComp) {

$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart Computer' -RunAfterRestart HardDisk -MessageTimeout 5 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $ClientCustomisation.Name -InsertStepStartIndex 4 -AddStep $RestartComp
}


<###############################################################################

Restore User Data Group
 
################################################################################>


Write-Host "Creating USMT Restore TS Steps.." -ForegroundColor Yellow 


$GetRestoreUserData = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Restore User Data' | Where-Object {$_.Condition -match 'RefreshComputer' -and $_.Condition -match 'ReplaceComputer' }

if (!$GetRestoreUSerData ) 
{

$USMTRestoreCondition = New-CMTaskSequenceStepConditionIfStatement -StatementType Any -Condition ($BuildTypeRefreshVar,$BuildTypeReplaceVar)
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Restore User Data' -AddCondition $USMTRestoreCondition

}

$GetRestoreOptions = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName "USMT - Set Additional Restore Options - Windows"

if (!$GetRestoreOptions ) {

$USMTPkgID = $USMTPkg.PackageID
$AdditionalRestoreOptions = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Restore Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalRestoreOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $AdditionalRestoreOptions -InsertStepStartIndex 0

}

$GetRestoreHardLinks = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "USMT - HardLinks"

if (!$GetRestoreHardLinks ) {
$USMTRestoreHardlinks = New-CMTaskSequenceGroup -Name "USMT - HardLinks"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreHardlinks -InsertStepStartIndex 2
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - HardLinks' -AddCondition $BuildTypeRefreshVar

}


#Check whether the SMP Group exists 
$GetRestoreSMP = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "USMT - State Migration Point"

if (!$GetRestoreSMP) {

# Create USMT SMP Group
$USMTRestoreSMP = New-CMTaskSequenceGroup -Name "USMT - State Migration Point"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreSMP -InsertStepStartIndex 3
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - State Migration Point' -AddCondition $BuildTypeReplaceVar

}

$GetRequestStateStore = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'USMT - Request State Store' 

if (!$GetRequestStateStore) { 

$RequestStateStore = New-CMTaskSequenceStepRequestStateStore -RetryCount 3 -RequestOption Restore -FallbackToAccount $true -Name 'USMT - Request State Store'
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - State Migration Point' -AddStep $RequestStateStore -InsertStepStartIndex 0
}

$GetReleaseStateStore = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'USMT - Release State Store' 

if (!$GetReleaseStateStore ) { 
$ReleaseStateStore = New-CMTaskSequenceStepReleaseStateStore -Name 'USMT - Release State Store' 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - State Migration Point' -AddStep $ReleaseStateStore -InsertStepStartIndex 2

} 




<###############################################################################

Activation 
 
################################################################################>
Write-Host "Creating Activation TS Steps.." -ForegroundColor Yellow 

$GetActivateWindows = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName "Activate Windows"

if(!$GetActivateWindows) {

$ActivateWindows = New-CMTaskSequenceStepRunCommandLine -StepName "Activate Windows" -CommandLine 'cscript.exe "%windir%\system32\slmgr.vbs" /ato'
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Activation.Name -AddStep $ActivateWindows

}

Else { 

Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Activate Windows" -CommandLine 'cscript.exe "%windir%\system32\slmgr.vbs" /ato'

}


<###############################################################################

Windows Updates  
 
################################################################################>

Write-Host "Creating Windows Update TS Steps.." -ForegroundColor Yellow 


$GetRestartComp = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Updates.Name | Where-Object {$_.Steps -match 'Restart Computer' }

if(!$GetRestartComp) {

$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart Computer' -RunAfterRestart HardDisk -MessageTimeout 5 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Updates.Name -InsertStepStartIndex 0 -AddStep ($RestartComp)
}


$UpdatesSteps = @("Scan for Updates","Install Microsoft Updates")

$UpdatesTable = @{

CommandLine1 = New-CMTaskSequenceStepRunCommandLine -StepName "Scan for Updates" -CommandLine 'WMIC /namespace:\\root\ccm path sms_client CALL TriggerSchedule "{00000000-0000-0000-0000-000000000113}" /NOINTERACTIVE'

CommandLine2 = New-CMTaskSequenceStepInstallUpdate -StepName 'Install Microsoft Updates' -Target All -RetryCount 5 -UseCache $true 

}

$i = 0

foreach ($Step in $UpdatesSteps ) {


$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if(!$StepName) { 

Write-Host "Creating Windows Update TS Step: $Step" -ForegroundColor Green

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Updates.Name -AddStep $UpdatesTable['CommandLine'+"$i"] -InsertStepStartIndex $i 

}

Else { 

Switch ($step) {

"Scan for Updates" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Scan for Updates" -CommandLine 'WMIC /namespace:\\root\ccm path sms_client CALL TriggerSchedule "{00000000-0000-0000-0000-000000000113}" /NOINTERACTIVE'}
"Install Microsoft Updates"{ Set-CMTaskSequenceStepInstallUpdate -TaskSequenceName $TS.Name -StepName 'Install Microsoft Updates' -Target All -RetryCount '5' -UseCache 'True' }

}

}

}
 

<###############################################################################

Finalise  
 
################################################################################>


Write-Host "Creating Finalise Group TS Steps.." -ForegroundColor Yellow 

$FinaliseSteps = @("Enable Bitlocker","CopyBuildLogs")

$FinaliseTable = @{

CommandLine1 = New-CMTaskSequenceStepEnableBitLocker -Name "Enable Bitlocker" -TpmOnly -CreateKeyOption ActiveDirectoryDomainServices -verbose

CommandLine2 = New-CMTaskSequenceStepRunCommandLine -StepName "CopyBuildLogs" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$CopyBuildLogs" -PackageId $BuildScriptsPkg.PackageID

}

$i = -1
$a = 0


foreach ($Step in $FinaliseSteps ) {

$a++
$i++

$StepName = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName $Step

if(!$StepName) { 

Write-Host "Creating Finalise Group TS Step: $Step" -ForegroundColor Green 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Finalise.Name -AddStep $FinaliseTable['CommandLine'+"$a"] -InsertStepStartIndex $i 

}

Else { 

switch ($Step) 

{

"Enable Bitlocker" { Set-CMTaskSequenceStepEnableBitLocker -TaskSequenceName $TS.Name -StepName "Enable Bitlocker" -TpmOnly -CreateKeyOption ActiveDirectoryDomainServices }
"CopyBuildLogs" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "CopyBuildLogs" -CommandLine "powershell.exe -executionPolicy Bypass -file .\$CopyBuildLogs" -PackageId $BuildScriptsPkg.PackageID }

}

}

}

