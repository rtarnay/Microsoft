

#Creates a new  Windows 10 OSD Task Sequence 
#Will recreate any steps,groups or conditions if they have been deleted or modified
#Automatically add any new Driver Packs and Tier 1 Applications to Task Sequence 
#Tested with ConfigMgr Technical Preview 1711

$ErrorActionPreference = 'SilentlyContinue'


#Client Specific Settings 
$DJuserpassword = Get-Credential
$TaskSequenceName = 'Deploy - Windows 10 Enterprise'
$ConfigMgrServer = '' 
$DJAccount = ''
$Domain = ''
$OU = 'LDAP://OU=Workstations,OU=Contoso,DC=contoso,DC=com'
$UserName = ''
$OrganisationName = ''
$OSName = 'Windows 10*'
$BuildScriptsPackage = Get-CMPackage -Name '*Build Scripts*'
$USMTPackage = Get-CMPackage -Name '*User State Migration*'

#Import ConfigMgr PowerShell Module 

Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")

$SiteCode = Get-PSDrive -PSProvider CMSITE

Set-Location "$($SiteCode.Name):\"


#Set Common Task Sequence Conditional Variables Here 

$WinPETrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'True'
$WinPEFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'False'

$UEFITrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'True'
$UEFIFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'False'

$BuildTypeRefreshVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'RefreshComputer'
$BuildTypeReplaceVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'ReplaceComputer'

$BdeTrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'True'
$BdeFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'False'



# Create a new Task Sequence

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

#Get Task Sequence Groups 

$Preparation = New-CMTaskSequenceGroup -Name "Preparation"
$USMTCapture = New-CMTaskSequenceGroup -Name "Capture User Data"
$InstallOS = New-CMTaskSequenceGroup -Name "Install Operating System"
$Drivers = New-CMTaskSequenceGroup -Name "Apply Device Drivers"
$SetupOS = New-CMTaskSequenceGroup -Name "Setup OperatingSystem"
$Tier1Apps = New-CMTaskSequenceGroup -Name "Install Tier 1 Applications"
$ClientCustomisation = New-CMTaskSequenceGroup -Name "Apply Client Config"
$USMTRestore = New-CMTaskSequenceGroup -Name "Restore User Data"
$Activation = New-CMTaskSequenceGroup -Name "Run Windows Activation"
$Updates = New-CMTaskSequenceGroup -Name "Windows Updates"
$Finalise = New-CMTaskSequenceGroup -Name "Finalise"




<###############################################################################

Preparation Group 
 
################################################################################>

Write-Host "Creating Preparation TS Steps.." -ForegroundColor Yellow 

$PreparationSteps = @(
"Set OSDBuildVersion",`
"Set SMSTSDownloadRetryCount",`
"Set SMSTSDownloadRetryDelay",`
"Set SMSTSPostAction"
) 

$PreparationTable = @{

TSVariable1 = New-CMTaskSequenceStepSetVariable -Name "Set OSDBuildVersion" -TaskSequenceVariable 'OSDBuildVersion' -TaskSequenceVariableValue '1.0'

TSVariable2 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSDownloadRetryCount" -TaskSequenceVariable 'SMSTSDownloadRetryCount' -TaskSequenceVariableValue '5'

TSVariable3 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSDownloadRetryDelay" -TaskSequenceVariable 'SMSTSDownloadRetryDelay' -TaskSequenceVariableValue '15' 

TSVariable4 = New-CMTaskSequenceStepSetVariable -Name "Set SMSTSPostAction" -TaskSequenceVariable 'SMSTSPostAction' -TaskSequenceVariableValue 'shutdown.exe -r -t 00' 

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
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $WinPE -InsertStepStartIndex 4 
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

$PartitionDisk = New-CMTaskSequenceStepPartitionDisk -DiskType Gpt -DiskNumber 0 -Name 'Partition Disk - Partitionless Machine - WinPE' -PartitionSetting ($PartSetting1,$PartSetting2,$PartSetting3,$PartSetting4)
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
 

 #Set Bitlocker Variable

$GetBitlockerVar = Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Set BitlockerVariable'

If (!$GetBitlockerVar) {

$SetBitlockerVar = New-CMTaskSequenceStepRunCommandLine -StepName "Set BitlockerVariable" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Set_BitlockerVariable.ps1" -PackageId $BuildScriptsPackage.PackageID
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $SetBitlockerVar -InsertStepStartIndex 5

}

Else {
      Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set BitlockerVariable" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Set_BitlockerVariable.ps1" -PackageId $BuildScriptsPackage.PackageID  

 }



<###############################################################################

Capture User Data Group
 
################################################################################>

Write-Host "Creating USMT Capture TS Steps.." -ForegroundColor Yellow 

$USMTPkgID = $USMTPAckage.PackageID
$CaptureUserData = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data'


$USMTCaptureCondition = $CaptureUserData.Condition.Operands | Where-Object {$_.Variable -eq 'BuildType' -and $_.Value -eq 'RefreshComputer' }

If(!$USMTCaptureCondition) {
 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data' -RemoveConditionVariable
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data' -AddCondition $BuildTypeRefreshVar

}



$USMTCaptureSteps = @(
"Check IsBDE",`
"Disable Bitlocker",`
"USMT - Set Additional Capture Options - Windows",`
"USMT - Set OSDStateStore"

) 

$USMTCaptureTable = @{

USMTStep1 = New-CMTaskSequenceStepRunCommandLine -StepName "Check IsBDE" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_IsBDE_Variable.ps1" -PackageId $BuildScriptsPackage.PackageID

USMTStep2 = New-CMTaskSequenceStepRunCommandLine -StepName "Disable Bitlocker" -CommandLine "manage-bde -protectors -disable C: " -Condition $BdeTrue

USMTStep3 = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Capture Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalCaptureOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*" 

USMTStep4 = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set OSDStateStore' -TaskSequenceVariable 'OSDStateStore' -TaskSequenceVariableValue 'C:\OSDStateStore'


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

 "Check IsBDE" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Check IsBDE" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_IsBDE_Variable.ps1" -PackageId $BuildScriptsPackage.PackageID }
 "Disable Bitlocker" { $DisableBitlocker = Get-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Disable Bitlocker"
 $DisableBitlocker = $DisableBitlocker.Condition.Operands | Where-Object {$_.Variable -eq 'IsBde' -and $_.Value -eq 'True' }
  
    Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Disable Bitlocker" -CommandLine "manage-bde -protectors -disable C:"

if (!$DisableBitlocker) { 

Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Disable Bitlocker" -CommandLine "manage-bde -protectors -disable C:" -ClearConditions 

Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Disable Bitlocker" -CommandLine "manage-bde -protectors -disable C:" -AddCondition $BdeTrue

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

$ImagePackage = Get-CMOperatingSystemImage -Name $OSName
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
"PreProvision Bitlocker",`
"Apply Operating System Image",`
"Set OSDComputerName",`
"Apply Windows Settings",`
"Apply Network Settings"
) 

$InstallOSTable = @{

InstallOSStep1 = New-CMTaskSequenceStepRunCommandLine -StepName "Set AES256 Encryption " -CommandLine "powershell.exe -executionpolicy Bypass -file ./Build_Bitlocker_AES256.ps1" -PackageId $BuildScriptsPackage.PackageID

InstallOSStep2 = New-CMTaskSequenceStepRunCommandLine -StepName "PreProvision Bitlocker" -CommandLine "OSDOfflineBitlocker.exe /enable /drive:$env:SystemDrive /ignoretpm:True" -Condition $BdeFalse

InstallOSStep3 = New-CMTaskSequenceStepApplyOperatingSystem -ImagePackage $ImagePackage -Destination SpecificLogicalDriverLetter -DestinationDriveLetter 'C:' -ImagePackageIndex 1 -Name 'Apply Operating System Image' -ConfigFileName Unattend.xml -ConfigFilePackage $BuildScriptsPackage 

InstallOSStep4 = New-CMTaskSequenceStepRunCommandLine -StepName "Set OSDComputerName" -CommandLine "powershell.exe -executionpolicy Bypass -file ./Set_OSDComputerName.ps1" -PackageId $BuildScriptsPackage.PackageID

InstallOSStep5 = New-CMTSStepApplyWindowsSetting -Name 'Apply Windows Settings' -UserName $UserName  -OrganizationName $OrganisationName -ServerLicensing NotSpecified -TimeZone $TimeZone

InstallOSStep6 = New-CMTaskSequenceStepApplyNetworkSetting -Name 'Apply Network Settings' -DomainName $Domain -DomainOU $OU -UserName $DJAccount -UserPassword $DJuserpassword.Password 

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

"Set AES256 Encryption"  { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set AES256 Encryption" -CommandLine "powershell.exe -executionpolicy Bypass -file ./Build_Bitlocker_AES256.ps1" -PackageId $BuildScriptsPackage.PackageID }
"Apply Operating System Image" { Set-CMTaskSequenceStepApplyOperatingSystem -TaskSequenceName $Ts.Name -ImagePackage $ImagePackage -Destination SpecificLogicalDriverLetter -DestinationDriveLetter 'C:' -ImagePackageIndex 1 -Name 'Apply Operating System Image' -ConfigFileName Unattend.xml -ConfigFilePackage $BuildScriptsPackage }
"Set OSDComputerName" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Set OSDComputerName" -CommandLine "powershell.exe -executionpolicy Bypass -file ./Set_OSDComputerName.ps1" -PackageId $BuildScriptsPackage.PackageID}
"Apply Windows Settings" { Set-CMTSStepApplyWindowsSetting -TaskSequenceName $TS.Name -Name 'Apply Windows Settings' -UserName $UserName  -OrganizationName $OrganisationName -ServerLicensing NotSpecified -TimeZone $TimeZone}
"Apply Network Settings" { Set-CMTaskSequenceStepApplyNetworkSetting -TaskSequenceName $TS.Name -Name 'Apply Network Settings' -DomainName $Domain -DomainOU $OU -UserName $DJAccount -UserPassword $DJuserpassword.Password}

"PreProvision Bitlocker" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker" -CommandLine "OSDOfflineBitlocker.exe /enable /drive:$env:SystemDrive /ignoretpm:True"

$GetPreProvBde = Get-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker"
$GetPreProvBde = $GetPreProvBde.Condition.Operands | Where-Object {$_.Variable -eq 'ISBDe' -and $_.Value -eq 'False'}

if (!$GetPreProvBde) {
Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker" -RemoveConditionVariable
Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "PreProvision Bitlocker" -CommandLine "OSDOfflineBitlocker.exe /enable /drive:$env:SystemDrive /ignoretpm:True" -AddCondition $BdeFalse 

}

}

}

}

}


<###############################################################################

Apply Device Drivers 
 
################################################################################>

Write-Host "Creating Apply Drivers TS Steps.." -ForegroundColor Yellow 

$DriverPacks = Get-CMDriverPackage | Select Name -ExpandProperty Name

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

$CMClientPackage = Get-CMPackage -Name 'Configuration Manager Client*'

$GetSetupOSStep =  Get-CMTaskSequenceStep -TaskSequenceName $TS.Name -StepName 'Setup Windows and ConfigMgr'

if (!$GetSetupOSStep)
{

$SetupWindowsCfgMgr = New-CMTaskSequenceStepSetupWindowsAndConfigMgr -PackageId $CMClientPackage.PackageID -Name 'Setup Windows and ConfigMgr' -InstallationProperty "SMSCACHESIZE=20480 SMSMP=$ConfigMgrServer FSP=$ConfigMgrServer"
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

CommandLine1 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Windows Features" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureWindowsFeatures.ps1" -PackageId $BuildScriptsPackage.PackageID 

CommandLine2 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Universal Apps" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureUniversalApplications.ps1" -PackageId $BuildScriptsPackage.PackageID 

CommandLine3 = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Machine Config" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_MachineConfig.ps1" -PackageId $BuildScriptsPackage.PackageID 

}


$ClientConfigSteps = @(
"Configure Windows Features",`
"Configure Universal Apps",`
"Configure Machine Config")

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

"Configure Windows Features"{Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Windows Features" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureWindowsFeatures.ps1" -PackageId $BuildScriptsPackage.PackageID}
"Configure Universal Apps"{Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Universal Apps" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureUniversalApplications.ps1" -PackageId $BuildScriptsPackage.PackageID}
"Configure Machine Config" {Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "Configure Machine Config" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_MachineConfig.ps1" -PackageId $BuildScriptsPackage.PackageID }

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

$USMTPkgID = $USMTPAckage.PackageID
$AdditionalRestoreOptions = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Restore Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalRestoreOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $AdditionalRestoreOptions -InsertStepStartIndex 0

}

$GetRestoreHardLinks = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "USMT - HardLinks"

if (!$GetRestoreHardLinks ) {
$USMTRestoreHardlinks = New-CMTaskSequenceGroup -Name "USMT - HardLinks"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreHardlinks -InsertStepStartIndex 2
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - HardLinks' -AddCondition $BuildTypeRefreshVar

}

$GetRestoreSMP = Get-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName "USMT - State Migration Point"

if (!$GetRestoreSMP) {

# Create USMT SMP Group
$USMTRestoreSMP = New-CMTaskSequenceGroup -Name "USMT - State Migration Point"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreSMP -InsertStepStartIndex 3
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - State Migration Point' -AddCondition $BuildTypeReplaceVar

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

CommandLine2 = New-CMTaskSequenceStepRunCommandLine -StepName "CopyBuildLogs" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_CopyOSDLogs.ps1" -PackageId $BuildScriptsPackage.PackageID

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
"CopyBuildLogs" { Set-CMTaskSequenceStepRunCommandLine -TaskSequenceName $TS.Name -StepName "CopyBuildLogs" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_CopyOSDLogs.ps1" -PackageId $BuildScriptsPackage.PackageID }

}

}

}

