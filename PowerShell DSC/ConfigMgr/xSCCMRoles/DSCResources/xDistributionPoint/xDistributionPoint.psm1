

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName
    )

    
    Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null

   
    $PSD = Get-PSDrive -PSProvider CMSite
    CD "$($PSD):"
     
    $DPInfo = Get-CMDistributionPointInfo -SiteSystemServerName $SiteSystemServerName -SiteCode $SiteCode

    $Result = @{    
                    
                    SiteCode             = $DPInfo.SiteCode
                    SiteSystemServerName = $DPInfo.ServerName
                    AllowPrestaging      = $Dpinfo.PreStagingAllowed
                    EnablePXE            = $DPInfo.IsPXE
                    EnableUnknownComputerSupport = $DPInfo.SupportUnknownMachines
                    Ensure = if ($DPInfo.ServerName -eq $SiteSystemServerName) {"Present"} else {"Absent" }
                    
                 }
    
                $Result
    
    

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    <#
    $returnValue = @{
    SiteCode = [System.String]
    SiteServerName = [System.String]
    MinimumFreeSpaceMB = [System.UInt32]
    CertificateExpirationTimeUtc = [System.String]
    CertificatePath = [System.String]
    CertificatePassword = [System.Management.Automation.PSCredential]
    Description = [System.String]
    InstallInternetServer = [System.Boolean]
    ClientConnectionType = [System.String]
    AllowProxyTraffic = [System.Boolean]
    EnableAnonymous = [System.Boolean]
    AllowPrestaging = [System.Boolean]
    EnablePxe = [System.Boolean]
    EnableUnknownComputerSupport = [System.Boolean]
    AllowPxeResponse = [System.Boolean]
    EnablePullDP = [System.Boolean]
    EnableSSL = [System.Boolean]
    AllowContentValidation = [System.Boolean]
    AllowFallbackForContent = [System.Boolean]
    Ensure = [System.String]
    }

    $returnValue
    #>
}




function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName,

        [System.UInt32]
        $MinimumFreeSpaceMB,

        [System.String]
        $CertificateExpirationTimeUtc,

        [System.String]
        $CertificatePath,

        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [System.String]
        $Description,

        [System.Boolean]
        $InstallInternetServer,

        [ValidateSet("Internet","InternetAndIntranet","Intranet")]
        [System.String]
        $ClientConnectionType,

        [System.Boolean]
        $AllowProxyTraffic,

        [System.Boolean]
        $EnableAnonymous,

        [System.Boolean]
        $AllowPrestaging,

        [System.Boolean]
        $EnablePxe,

        [System.Boolean]
        $EnableUnknownComputerSupport,

        [System.Boolean]
        $AllowPxeResponse,

        [System.Boolean]
        $EnablePullDP,

        [System.Boolean]
        $EnableSSL,

        [System.Boolean]
        $AllowContentValidation,

        [System.Boolean]
        $AllowFallbackForContent,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )



Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null
    
    $PSD = Get-PSDrive -PSProvider CMSite
    CD "$($PSD):"

    $DP = Get-CMDistributionPoint -SiteCode $SiteCode -SiteSystemServerName $SiteSystemServerName 

    if ($DP ) { 
            
       Set-CMDistributionPoint `
             -SiteSystemServerName $SiteSystemServerName `
             -SiteCode $SiteCode `
             -AllowPreStaging $AllowPrestaging `
             -EnablePxe $EnablePxe `
             -EnableUnknownComputerSupport $EnableUnknownComputerSupport `
             -Verbose
            
    }

    Else {  
     
     Add-CMDistributionPoint  `
             -SiteSystemServerName $SiteSystemServerName `
             -SiteCode $SiteCode `
             -CertificateExpirationTimeUtc $CertificateExpirationTimeUtc `
             -InstallInternetServer $InstallInternetServer `
             -AllowPreStaging $AllowPrestaging `
             -EnablePxe $EnablePxe `
             -EnableUnknownComputerSupport $EnableUnknownComputerSupport `
             -EnableContentValidation $AllowContentValidation `
             -MinimumFreeSpaceMB $MinimumFreeSpaceMB `
             -ClientConnectionType $ClientConnectionType `
             -Verbose 
                         
    
    }

    
    

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1


}



function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName,

        [System.UInt32]
        $MinimumFreeSpaceMB,

        [System.String]
        $CertificateExpirationTimeUtc,

        [System.String]
        $CertificatePath,

        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [System.String]
        $Description,

        [System.Boolean]
        $InstallInternetServer,

        [ValidateSet("Internet","InternetAndIntranet","Intranet")]
        [System.String]
        $ClientConnectionType,

        [System.Boolean]
        $AllowProxyTraffic,

        [System.Boolean]
        $EnableAnonymous,

        [System.Boolean]
        $AllowPrestaging,

        [System.Boolean]
        $EnablePxe,

        [System.Boolean]
        $EnableUnknownComputerSupport,

        [System.Boolean]
        $AllowPxeResponse,

        [System.Boolean]
        $EnablePullDP,

        [System.Boolean]
        $EnableSSL,

        [System.Boolean]
        $AllowContentValidation,

        [System.Boolean]
        $AllowFallbackForContent,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )


    try {

    Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null
  
    $PSD = Get-PSDrive -PSProvider CMSite
    CD "$($PSD):"
   
    $DP = Get-CMDistributionPoint -SiteCode $SiteCode -SiteSystemServerName $SiteSystemServerName 
    $Dpinfo = Get-CMDistributionPointInfo -SiteSystemServerName $SiteSystemServerName -SiteCode $SiteCode 

    if (
        $DPInfo.IsPXE -eq $EnablePxe -and
        $Dpinfo.SupportUnknownMachines -eq $EnableUnknownComputerSupport -and
        $Dpinfo.PreStagingAllowed -eq $AllowPrestaging -and
        $Ensure -eq "Present"
        
        )  { 
        
        
        $Result = $true 
        
        }
    
    else { $Result = $false }

    }

    catch {
    
    if ($Ensure -eq "Absent") {$Result =$true }
    else {$Result = $false} 

    }

    $Result

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."





    <#
    $result = [System.Boolean]
    
    $result
    #>
}


Export-ModuleMember -Function *-TargetResource

