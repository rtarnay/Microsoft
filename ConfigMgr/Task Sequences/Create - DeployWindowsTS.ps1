
#Client Specific Settings 
$DJuserpassword = Get-Credential
$TaskSequenceName = 'Test - Deploy Windows 10 Enterprise x64'
$ConfigMgrServer = 'cm02.contoso.com' 
$DJAccount = 'contoso\CM_DJ'
$Domain = 'contoso.com'
$OU = 'LDAP://OU=Workstations,OU=contosoLab,DC=contoso,DC=com'
$UserName = 'Contoso'
$OrganisationName = 'contoso'
$OSName = 'Windows 10*'
$BuildScriptsPackage = Get-CMPackage -Name '*Build Scripts*'
$USMTPackage = Get-CMPackage -Name '*User State Migration*'


#Common Conditional Variables 

$WinPETrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'True'
$WinPEFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSInWinPE' -ConditionVariableValue 'False'

$UEFITrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'True'
$UEFIFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName '_SMSTSBootUEFI' -ConditionVariableValue 'False'

$BuildTypeRefreshVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'RefreshComputer'
$BuildTypeReplaceVar = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'BuildType' -ConditionVariableValue 'ReplaceComputer'

$BdeTrue = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'True'
$BdeFalse = New-CMTSStepConditionVariable -OperatorType Equals -ConditionVariableName 'IsBDE' -ConditionVariableValue 'False'



# Create a new Task Sequence

Write-Host "Creating New Task Sequence.." -ForegroundColor Yellow 
$TS = New-CMTaskSequence -CustomTaskSequence -Name "$TaskSequenceName" -Description "A Custom Windows 10 Task Sequence"

Write-Host "Creating Task Sequence Groups.." -ForegroundColor Yellow 

#Create Task Sequence Groups

$Preparation = New-CMTaskSequenceGroup -Name "Preparation"
$USMTCapture = New-CMTaskSequenceGroup -Name "Capture User Data"
$InstallOS = New-CMTaskSequenceGroup -Name "Install Operating System"
$Drivers = New-CMTaskSequenceGroup -Name "Apply Device Drivers"
$SetupOS = New-CMTaskSequenceGroup -Name "Setup OperatingSystem"
$Tier1Apps = New-CMTaskSequenceGroup -Name "Install Tier 1 Applications"
$ClientCustomisation = New-CMTaskSequenceGroup -Name "Apply $OrganisationName Config"
$USMTRestore = New-CMTaskSequenceGroup -Name "Restore User Data"
$Activation = New-CMTaskSequenceGroup -Name "Run Windows Activation"
$Updates = New-CMTaskSequenceGroup -Name "Windows Updates"
$Finalise = New-CMTaskSequenceGroup -Name "Finalise"

Add-CMTaskSequenceStep -InsertStepStartIndex 0 -TaskSequenceName $TS.Name -Step `
($Preparation,`
$USMTCapture,`
$InstallOS,`
$Drivers,`
$SetupOS,`
$Tier1Apps,`
$ClientCustomisation,`
$USMTRestore,`
$Activation,`
$Updates,`
$Finalise )
 

<###############################################################################

Preparation Group 
 
################################################################################>

Write-Host "Creating Preparation TS Steps.." -ForegroundColor Yellow 

#Set Preparation Group Task Sequence Variables
$PrepVar1 = New-CMTaskSequenceStepSetVariable -Name 'Set OSDBuildVersion' -TaskSequenceVariable 'OSDBuildVersion' -TaskSequenceVariableValue '1.0' 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $PrepVar1 -InsertStepStartIndex 0 

$PrepVar2 = New-CMTaskSequenceStepSetVariable -Name 'Set SMSTSDownloadRetryCount' -TaskSequenceVariable 'SMSTSDownloadRetryCount' -TaskSequenceVariableValue '5' 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $PrepVar2 -InsertStepStartIndex 1

$PrepVar3 = New-CMTaskSequenceStepSetVariable -Name 'Set SMSTSDownloadRetryDelay' -TaskSequenceVariable 'SMSTSDownloadRetryDelay' -TaskSequenceVariableValue '15' 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $PrepVar3 -InsertStepStartIndex 2


$PreFlight = New-CMTaskSequenceGroup -Name "PreFlight Checks"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $PreFlight -InsertStepStartIndex 3

#Create the Pre Flight Run Command Line action
$PreFlightPackage = Get-CMPackage -Name *PreFlight*
$RunPreFlightChecks = New-CMTaskSequenceStepRunCommandLine -StepName "Run OSD-PreFlight-Checks" -CommandLine "ServiceUI.exe -process:TSProgressUI.exe %windir%\System32\WindowsPowershell\V1.0\powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File OSD_PreFlight_Checks.ps1" -PackageId $PreFlightPackage.PackageID
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $PreFlight.Name -AddStep $RunPreFlightChecks -InsertStepStartIndex 0

# Create WinPE group
$WinPE = New-CMTaskSequenceGroup -Name "WinPE"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $WinPE -InsertStepStartIndex 4 -AddCondition ($WinPETrue,$UEFITrue)


#Create Format and Partition Disk Step in WinPE Group 
$PartSetting1 = New-CMTSPartitionSetting -Name 'Windows Recovery' -PartitionRecovery -Size 300 -SizeUnit MB
$PartSetting2 = New-CMTSPartitionSetting -Name 'EFI' -PartitionEfi -Size 500 -SizeUnit MB 
$PartSetting3 = New-CMTSPartitionSetting -Name 'MSR' -PartitionMsr -Size 128 -SizeUnit MB 
$PartSetting4 = New-CMTSPartitionSetting -Name 'OSDisk' -PartitionPrimary -Size 100 -SizeUnit Percent -EnableQuickFormat $true -PartitionFileSystem Ntfs

$PartitionDisk = New-CMTaskSequenceStepPartitionDisk -DiskType Gpt -DiskNumber 0 -Name 'Partition Disk - Partitionless Machine - WinPE' -PartitionSetting ($PartSetting1,$PartSetting2,$PartSetting3,$PartSetting4)
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $WinPE.Name -AddStep $PartitionDisk -InsertStepStartIndex 0

# Add Restart Step 
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart in WinPE' -RunAfterRestart WinPE -MessageTimeout 10 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $WinPE.Name -AddStep $RestartComp -InsertStepStartIndex 1 

 #Set Bitlocker Variable
$SetBitlockerVar = New-CMTaskSequenceStepRunCommandLine -StepName "Set BitlockerVariable" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Set_BitlockerVariable.ps1" -PackageId $BuildScriptsPackage.PackageID
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $SetBitlockerVar -InsertStepStartIndex 7

$SetPowerPlan = New-CMTaskSequenceStepRunCommandLine -StepName "Set PowerPlan - High Performance" -CommandLine "PowerCfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Preparation.Name -AddStep $SetPowerPlan -InsertStepStartIndex 8



<###############################################################################

Capture User Data Group
 
################################################################################>

Write-Host "Creating USMT Capture TS Steps.." -ForegroundColor Yellow 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Capture User Data' -AddCondition $BuildTypeRefreshVar

$BdeFalseVar = New-CMTaskSequenceStepRunCommandLine -StepName "Check IsBDE" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_IsBDE_Variable.ps1" -PackageId $BuildScriptsPackage.PackageID

$DisableBitlocker = New-CMTaskSequenceStepRunCommandLine -StepName "Disable Bitlocker" -CommandLine "manage-bde -protectors -disable C: " -Condition $BdeTrue

$USMTPkgID = $USMTPAckage.PackageID
$AdditionalCaptureOptions = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Capture Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalCaptureOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*" 

$OSDStateStore = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set OSDStateStore' -TaskSequenceVariable 'OSDStateStore' -TaskSequenceVariableValue 'C:\OSDStateStore'

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTCapture.Name -AddStep `
    ($BdeFalseVar,`
    $DisableBitlocker,`
    $AdditionalCaptureOptions,`
    $OSDStateStore)


<###############################################################################

Install Operating System
 
################################################################################>

Write-Host "Creating Install OS TS Steps.." -ForegroundColor Yellow 

# Add Restart Step 
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart WinPE' -RunAfterRestart WinPE -MessageTimeout 10 -Condition $WinPEFalse

#Set AES_256 Encryption 
$AES256Encryption = New-CMTaskSequenceStepRunCommandLine -StepName "Set AES256 Encryption " -CommandLine "powershell.exe -executionpolicy Bypass -file ./Build_Bitlocker_AES256.ps1" -PackageId $BuildScriptsPackage.PackageID


#Add Preprovision Bitlocker Step 
$PreprovisionBitlocker = New-CMTaskSequenceStepRunCommandLine -StepName "PreProvision Bitlocker" -CommandLine "OSDOfflineBitlocker.exe /enable /drive:$env:SystemDrive /ignoretpm:True" -Condition $BdeFalse

#Add Apply Operating Sytem Step
$ImagePackage = Get-CMOperatingSystemImage -Name $OSName
$ApplyOS = New-CMTaskSequenceStepApplyOperatingSystem -ImagePackage $ImagePackage -Destination SpecificLogicalDriverLetter -DestinationDriveLetter 'C:' -ImagePackageIndex 1 -Name 'Apply Operating System Image' -ConfigFileName Unattend.xml -ConfigFilePackage $BuildScriptsPackage 


#Add Set OSD ComputerName 
$SetOSDComputerName = New-CMTaskSequenceStepRunCommandLine -StepName "Set OSDComputerName" -CommandLine "powershell.exe -executionpolicy Bypass -file ./Set_OSDComputerName.ps1" -PackageId $BuildScriptsPackage.PackageID

#Apply Windows Settings
$TimeZone = Get-TimeZone
$ApplyWindowsSettings = New-CMTSStepApplyWindowsSetting -Name 'Apply Windows Settings' -UserName $UserName  -OrganizationName $OrganisationName -ServerLicensing NotSpecified -TimeZone $TimeZone

#Apply Network Settings 
$ApplyNetworkSettings = New-CMTaskSequenceStepApplyNetworkSetting -Name 'Apply Network Settings' -DomainName $Domain -DomainOU $OU -UserName $DJAccount -UserPassword $DJuserpassword.Password


Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $InstallOS.Name -AddStep `
 ($RestartComp,`
 $AES256Encryption,`
 $PreprovisionBitlocker,`
 $ApplyOS,`
 $SetOSDComputerName,`
 $ApplyWindowsSettings,`
 $ApplyNetworkSettings) 

<###############################################################################

Apply Device Drivers 
 
################################################################################>

Write-Host "Creating Apply Drivers TS Steps.." -ForegroundColor Yellow 

$DriverPacks = Get-CMDriverPackage | Select Name -ExpandProperty Name

ForEach ($DriverPack in $DriverPacks ) { 
 
 $DriverPackName = (Get-CMDriverPackage -Name $DriverPack).Name
 $DriverPackId = (Get-CMDriverPackage -Name $DriverPack).PackageId

 $WmiQuery = New-CMTaskSequenceStepConditionQueryWMI -Query "Select * from win32_computersystem WHERE model like '%$DriverPackName%'" 

 $ApplyDriverPack = New-CMTaskSequenceStepApplyDriverPackage -Name $DriverPackName -PackageId $DriverPackId -Condition $WmiQuery

 Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Drivers.Name -AddStep $ApplyDriverPack
  
} 



<###############################################################################

Setup Operating System  
 
################################################################################>

Write-Host "Creating Setup OS TS Steps.." -ForegroundColor Yellow 

$CMClientPackage = Get-CMPackage -Name 'Configuration Manager Client*'

$SetupWindowsCfgMgr = New-CMTaskSequenceStepSetupWindowsAndConfigMgr -PackageId $CMClientPackage.PackageID -Name 'Setup Windows and ConfigMgr' -InstallationProperty "SMSCACHESIZE=20480 SMSMP=$ConfigMgrServer FSP=$ConfigMgrServer"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $SetupOS.Name -AddStep $SetupWindowsCfgMgr


<###############################################################################

Install Applications  
 
################################################################################>

Write-Host "Creating Install Tier 1 Apps.." -ForegroundColor Yellow 

$Applications = Get-CMApplication | Where-Object {$_.LocalizedCategoryInstanceNames -eq 'Tier 1'} 
$Apps = New-CMTaskSequenceStepInstallApplication -Name 'Install Tier 1 Apps' -Application $Applications -ContinueOnInstallError 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Tier1Apps.Name -AddStep $Apps


<###############################################################################

Apply Client Customisations 
 
################################################################################>

Write-Host "Creating Apply Client Customistations TS Steps.." -ForegroundColor Yellow 

$WindowsFeatures = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Windows Features" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureWindowsFeatures.ps1" -PackageId $BuildScriptsPackage.PackageID
$UniversalApps = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Universal Apps" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_ConfigureUniversalApplications.ps1" -PackageId $BuildScriptsPackage.PackageID
$MachineConfig = New-CMTaskSequenceStepRunCommandLine -StepName "Configure Machine Config" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_MAchineConfig.ps1" -PackageId $BuildScriptsPackage.PackageID
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart Computer' -RunAfterRestart HardDisk -MessageTimeout 5 

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $ClientCustomisation.Name -AddStep ($WindowsFeatures,$UniversalApps,$MachineConfig,$RestartComp) -InsertStepStartIndex 0


<###############################################################################

Restore User Data Group
 
################################################################################>

Write-Host "Creating USMT Restore TS Steps.." -ForegroundColor Yellow 


$USMTRestoreCondition = New-CMTaskSequenceStepConditionIfStatement -StatementType Any -Condition ($BuildTypeRefreshVar,$BuildTypeReplaceVar)
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'Restore User Data' -AddCondition $USMTRestoreCondition



$USMTPkgID = $USMTPAckage.PackageID
$AdditionalCaptureOptions = New-CMTaskSequenceStepSetVariable -Name 'USMT - Set Additional Restore Options - Windows' -TaskSequenceVariable 'OSDMigrateAdditionalRestoreOptions' -TaskSequenceVariableValue "/config:C:\_SMSTaskSequence\Packages\$USMTPkgID\Config.xml /ue:%computername%\*"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $AdditionalCaptureOptions -InsertStepStartIndex 0

# Create USMT HardLinks Group
$USMTRestoreHardlinks = New-CMTaskSequenceGroup -Name "USMT - HardLinks"
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreHardlinks -InsertStepStartIndex 2
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - HardLinks' -AddCondition $BuildTypeRefreshVar

# Create USMT SMP Group
$USMTRestoreSMP = New-CMTaskSequenceGroup -Name "USMT - State Migration Point "
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $USMTRestore.Name -AddStep $USMTRestoreSMP -InsertStepStartIndex 3
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName 'USMT - HardLinks' -AddCondition $BuildTypeReplaceVar

<###############################################################################

Activation 
 
################################################################################>
Write-Host "Creating Activation TS Steps.." -ForegroundColor Yellow 

$ActivateWindows = New-CMTaskSequenceStepRunCommandLine -StepName "Activate Windows" -CommandLine 'cscript.exe "%windir%\system32\slmgr.vbs" /ato'
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Activation.Name -AddStep $ActivateWindows


<###############################################################################

Windows Updates  
 
################################################################################>

Write-Host "Creating Windows Update TS Steps.." -ForegroundColor Yellow 

$RestartComp = New-CMTaskSequenceStepReboot -Name 'Restart Computer' -RunAfterRestart HardDisk -MessageTimeout 5 
$ScanUpdates = New-CMTaskSequenceStepRunCommandLine -StepName "Scan for Updates" -CommandLine 'WMIC /namespace:\\root\ccm path sms_client CALL TriggerSchedule "{00000000-0000-0000-0000-000000000113}" /NOINTERACTIVE'
$InstallUpdates = New-CMTaskSequenceStepInstallUpdate -Name 'Install Microsoft Updates' -Target All -RetryCount 5 -UseCache $true

Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Updates.Name -AddStep ($RestartComp,$ScanUpdates,$InstallUpdates) 

<###############################################################################

Finalise  
 
################################################################################>

Write-Host "Creating Finalise Group TS Steps.." -ForegroundColor Yellow 

$EnableBitlocker = New-CMTaskSequenceStepEnableBitLocker -Name 'Enable Bitlocker' -TpmOnly -CreateKeyOption ActiveDirectoryDomainServices 
$CopyLogs = New-CMTaskSequenceStepRunCommandLine -StepName "CopyBuildLogs" -CommandLine "powershell.exe -executionPolicy Bypass -file .\Build_CopyOSDLogs.ps1" -PackageId $BuildScriptsPackage.PackageID
$RestartComp = New-CMTaskSequenceStepReboot -Name 'Final Reboot' -RunAfterRestart HardDisk -MessageTimeout 5 
Set-CMTaskSequenceGroup -TaskSequenceName $TS.Name -StepName $Finalise.Name -AddStep ($EnableBitlocker,$CopyLogs,$RestartComp) 