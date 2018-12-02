

#BitLocker
#Credential Guard 
#AppLocker
#LAPS
#USB Removable Storage 

$User = "Contoso\Win10Test"
$ExeDownloadPath="C:\Temp\SpotifySetup.exe"

#BitLocker Tests

$Bitlocker = @{

VolumeType = "OperatingSystem"

VolumeStatus = "FullyEncrypted"

EncryptionPercent = "100"

ProtectionStatus = "On"

EncryptionMethod = "Aes256"

}


describe 'BitLocker Status' { 

$BDE = Get-BitLockerVolume -MountPoint C:


It 'Drive Type is OperatingSystem' { 
$BDE.VolumeType | Should be $Bitlocker.VolumeType

}


It "Encryption Method AES256" { 

$BDE.EncryptionMethod | Should be $Bitlocker.EncryptionMethod

}

It 'Encryption Percentage 100%' { 

$BDE.EncryptionPercentage | Should be $Bitlocker.EncryptionPercent

}

It 'Protection On' {

$BDE.ProtectionStatus | Should be $Bitlocker.ProtectionStatus

}

} 


#Credential Guard Tests

$CredentialGuard = @{ 

Enabled = "1"

Running = "LsaIso"

}


Describe 'CredentialGuard'{ 

$DevGuard = Get-CimInstance –ClassName Win32_DeviceGuard –Namespace root\Microsoft\Windows\DeviceGuard

$CGProc =  Get-Process -Name LsaIso

It "Credential Guard Configured" { 

$DevGuard.SecurityServicesConfigured | Should be $CredentialGuard.Enabled

}

It "Credential Guard Running" { 

$CGProc.Name | Should be $CredentialGuard.Running

}

}


#AppLocker Tests

$AppLocker = @{ 

Status = "Running"

PolicyDecision = "DeniedByDefault"

}

Describe 'AppLocker' { 

$AppIDSvc =  Get-Service -Name AppIDSvc

Invoke-WebRequest -Uri https://download.scdn.co/SpotifySetup.exe -UseBasicParsing -OutFile $ExeDownloadPath

$AppLockerPolicy = Get-AppLockerPolicy -Effective | Test-AppLockerPolicy -Path "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -User $User

$AppLockerPolicy2 = Get-AppLockerPolicy -Effective | Test-AppLockerPolicy -Path $ExeDownloadPath -User $User


it "AppLocker Running" { 

$AppIDSvc.Status | Should be $AppLocker.Status

}

It "PowerShell Blocked Rule" { 


$AppLockerPolicy.PolicyDecision | Should be $AppLocker.PolicyDecision

}

It "Self Contained Exe Blocked" { 

$AppLockerPolicy2.PolicyDecision | Should be $AppLocker.PolicyDecision

}


}


#LAPS Tests 

$LAPS = @{ 

AdmPwdEnabled = "1"
PwdExpirtationProtectionEnabled = "1"
PasswordAgeDays = "30"

}


Describe 'LAPS' {

$AdmPwd = Get-Item 'HKLM:\SOFTWARE\Policies\Microsoft Services\AdmPwd' | Get-ItemProperty 

It "LAPS Enabled" { 

$AdmPwd.AdmPwdEnabled | Should be $LAPS.AdmPwdEnabled

}

It "LAPS Password Expiration Protection" {

$AdmPwd.PwdExpirationProtectionEnabled | Should be $LAPS.PwdExpirtationProtectionEnabled

 }

It "Password Age Configuration" { 

$AdmPwd.PasswordAgeDays | Should be $LAPS.PasswordAgeDays

}

}

#Removable Storage Tests

Describe 'Block Removable Storage' { 


$USBAccess = Get-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' | Get-ItemProperty 

it "Deny USB Access" { 

$USBAccess.Deny_All | Should be '1'

}

}
