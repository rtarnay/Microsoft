﻿<#
    Script:Create_SiteServer_DP_SMP.ps1

    Author: Robbie Tarnay

    Last Modified: 06/02/2017
	
    .SYNOPSIS

		This script Creates a new ConfigMgr Site Server and installs the Distribution Point and SMP Roles.

	.NOTES
		 -Make sure the primary site server computer object local admin rights on all site servers to be provisioned as DP/SMP.
		 -IIS components are automatically installed on the site server when DP is installed 
		 -Distribution Point is enabled with PXE Support and Content Validation 
		 -State Migration Point folder is set to D:\State Migration Point" on line 74

	.PARAMETER SiteCode
		ConfigMgr Site Code 

    .PARAMETER SiteServerName
		FQDN of the ConfigMgr Site Server

    .PARAMETER BoundaryGroup
		The name of an existing boundary group that the DP and SMP will be assigned to.
	
	.EXAMPLE
		Create_SiteServer_DP_SMP.ps1 -SiteCode S01 -SiteServerName ContosoDP01 -BoundaryGroup Melbourne

#>



Param (
		[parameter(Mandatory = $true)]
		[string]$SiteCode,
        [parameter(Mandatory = $true)]
		[string]$SiteServerName,
		[parameter(Mandatory = $true)]
		[string]$BoundaryGroup
        
	) 

# Import Module

Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")

Set-Location $SiteCode +":\"

#Create SiteServer 

New-CMSiteSystemServer -SiteSystemServerName $SiteServerName -SiteCode $SiteCode -Verbose

#Install The Distribution Point Role

$DPParams = @{
    SiteSystemServerName = "CM02.tarnaylab.com"
    SiteCode = "TP1"
    CertificateExpirationTimeUtc = '2020/30/01 18:00:00'
    InstallInternetServer = $True
    AllowPrestaging = $True
    EnablePXE = $True
    EnableUnknownComputerSupport = $False
    MinimumFreeSpaceMB = '5000'
    AllowContentValidation = $True
    ClientConnectionType = 'Intranet'

}


Write-Host -Object('The Distribution role will be installed on Site Server {0}' -f $SMPParams.SiteSystemServerName )


Add-CMDistributionPoint @DPParams -Verbose



#Pester Test for Distribution Point Config

describe 'Distribution Point Configuration' {


	## Arrange/Act --execute the stuff to minimize code in the assertions
	$DPInfo = Get-CMDistributionPointInfo -SiteSystemServerName $SiteSystemServerName -SiteCode $SiteCode


	it 'Should be PXE Enabled' {
		$DPInfo.IsPXE | should be $DPParams.EnablePXE
	}

  
	it 'Unknown Computer Support Disabled ' {
		$DPInfo.SupportUnknownMachines | should be $DPParams.EnableUnknownComputerSupport
	}


	it 'Prestaging Content Enabled' {
		$DPInfo.PreStagingAllowed | should be $DPParams.AllowPrestaging
	}



	## .....
}



#Install the State Migration Point Role 

$SMPStorageFolder = New-CMStoragefolder -StorageFolderName "D:\State Migration Point" -MaximumClientNumber 100 -MinimumFreeSpace 1 -SpaceUnit 'Gigabyte'

$SMPParams = @{
SiteSystemServerName =$SiteServerName;
SiteCode = $SiteCode;
Storagefolders = $SMPStorageFolder;
TimeDeleteAfter = '7'
TimeUnit = 'Days'
EnableRestoreOnlyMode= $False;
AllowFallbackSourceLocationForContent = $False;
BoundaryGroupName = $BoundaryGroup; 
}


Write-Host -Object('The State Migration Point role will be installed on Site Server {0}. Data will be deleted after {1} days' -f $SMPParams.SiteSystemServerName, $SMPParams.TimeDeleteAfter )

Add-CMStateMigrationPoint @SMPParams -Verbose

