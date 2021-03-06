function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode
    )

 Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null
  
    $PSD = Get-PSDrive -PSProvider CMSite
     CD "$($PSD):"

 $Dpinfo = Get-CMDistributionPointInfo -SiteSystemServerName $SiteSystemServerName -SiteCode $SiteCode
  
    $returnValue = @{
    SiteSystemServerName = $Dpinfo.ServerName
    SiteCode = $Dpinfo.SiteCode
    UseSiteServerAccount = $true
    #EnableProxy = [System.Boolean]
    #ProxyServerName = [System.String]
    #ProxyServerPort = [System.UInt32]
    Ensure = $true
    }

    $returnValue
   
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode,

        [System.Boolean]
        $UseSiteServerAccount,

        [System.Boolean]
        $EnableProxy,

        [System.String]
        $ProxyServerName,

        [System.UInt32]
        $ProxyServerPort,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

   

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

   <# Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null
  
    $PSD = Get-PSDrive -PSProvider CMSite
    CD "$($PSD):"
   #>

   $SiteServer = Get-CMSiteSystemServer -SiteCode $SiteCode -SiteSystemServerName $SiteSystemServerName 

   if ($EnableProxy) {

    New-CMSiteSystemServer `
     -SiteCode $SiteCode `
     -SiteSystemServerName $SiteSystemServerName `
     -UseSiteServerAccount $UseSiteServerAccount `
     -EnableProxy $EnableProxy `
     -ProxyServerName $ProxyServerName `
     -ProxyServerPort $ProxyServerPort
    

     }

     Else { 
     
      New-CMSiteSystemServer `
     -SiteCode $SiteCode `
     -SiteSystemServerName $SiteSystemServerName `
     -UseSiteServerAccount $UseSiteSystemServerAccount 
     

     }
     
     
     

}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SiteSystemServerName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteCode,

        [System.Boolean]
        $UseSiteServerAccount,

        [System.Boolean]
        $EnableProxy,

        [System.String]
        $ProxyServerName,

        [System.UInt32]
        $ProxyServerPort,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

     try {

    Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1") | Out-Null
  
    $PSD = Get-PSDrive -PSProvider CMSite
     CD "$($PSD):"
   
    $SiteServer = Get-CMSiteSystemServer -SiteCode $SiteCode -SiteSystemServerName $SiteSystemServerName 
    

    if (
        
        $SiteServer.RoleName -eq 'SMS Site System' -and $Ensure -eq "Present" 

        
 
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


}


Export-ModuleMember -Function *-TargetResource

