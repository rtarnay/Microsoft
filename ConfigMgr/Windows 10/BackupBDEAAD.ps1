
#Creates a backup of the existing BitLocker Recovery Password in Azure AD
#Deploy script via ConfigMgr or other toolset such as Intune,Kaseya etc
#Author: Robbie Tarnay
#Date:29/02/2019


    # Logging Function 
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
		    [string]$FileName = "BackupBDE-AAD.log"
	    )
	    # Determine log file location
         $LogFilePath = Join-Path -Path "$env:windir\Temp" -ChildPath $FileName

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
     

#Check to see whether the BitLocker Recovery Key Exists

$BLV = (Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword' } 

#If it exists back up to Azure AD 

If ($BLV ) {

Write-CMLogEntry -Value "BitLocker Recovery Key Found on Computer $env:COMPUTERNAME" -Severity 1 

$RecoveryKey = Get-BitLockerVolume -MountPoint $env:SystemDrive

for ( $i = 0; $i -lt 2; $i++ ) {

$Protector = $RecoveryKey.KeyProtector[$i].KeyProtectorType

If ($Protector -eq 'RecoveryPassword') {

Try
{

Write-CMLogEntry -Value "Backing up BitLocker Recovery Key to Azure AD" -Severity 1

BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $RecoveryKey.KeyProtector[$i].KeyProtectorId 
 

if ($Error.Count -eq '0') { Write-CMLogEntry -Value "BitLocker Recovery Key successfully backed up to Azure AD" -Severity 1 }

}

Catch { 

 $ErrorMessage = $_.Exception.Message

 Write-CMLogEntry -Value "$ErrorMessage" -Severity 3 

} 


}

}

}

Else { 

Write-CMLogEntry -Value "BitLocker Recovery Key does not exist on Computer:$env:COMPUTERNAME" -Severity 2 


}