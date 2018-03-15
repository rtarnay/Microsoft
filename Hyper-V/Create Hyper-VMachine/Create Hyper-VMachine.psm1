##########################################################################
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2015 v4.2.83
# Created on:   23/05/2015 2:02 PM
# Created by:   rtarnay 
#-------------------------------------------------------------------------
# Module Name:  Create Hyper-VMachine
##########################################################################



function New-HyperVMachine

{
	
<#
	.SYNOPSIS
		This Module creates a New Hyper-V machine using the New-HyperVMachine function. 
	
	
	.PARAMETER CreateNewSwitch
		Boolean value to determine whether you would like to create a new Hyper-V Switch or use an existing Switch.
	
	.PARAMETER SwitchName
		The Name of your new or existing Hyper-V switch. 
	
	.PARAMETER SwitchType
		 Select Switch Type to create - External,Internal,Private
	
	.PARAMETER VMName
		The Name of your new Hyper-V instance.
	
	.PARAMETER VMLocation
		Location where the VM Files will be stored. 
	
	.PARAMETER VHDPath
		Location of your VHDX disk. 
	
	.PARAMETER VHDSize
		Size of the VHDX disk attached to be attached to VM.
	
	.PARAMETER StartUpMemSize
		Set the amount of memory to be used at startup by the Hyper-V Machine. 
	
	.EXAMPLE
		New-HyperVMachine -CreateNewSwitch False -SwitchName "External Ethernet Adaptor" -VMName "RTTestVM" -VMLocation "C:\Users\rtarnay\Hyper-V\Virtual Machines" -VHDPath "C:\users\rtarnay\Hyper-V\Virtual Machines\TestVM5.vhdx" -VHDSize 100MB -StartUpMemSize 1024MB

	
	.NOTES
		Additional information about the function.
#>
	
	Param (
		[parameter(Mandatory = $true)]
		[ValidateSet($true,$false)]
		[string]$CreateNewSwitch,
		[parameter(Mandatory = $true)]
		[string]$SwitchName,
		[parameter(Mandatory = $false)]
		[ValidateSet("Private","Internal","External")]
		[string]$SwitchType,
		[parameter(Mandatory = $true)]
		[string]$VMName,
		[parameter(Mandatory = $true)]
		[string]$VMLocation,
		[parameter(Mandatory = $true)]
		[string]$VHDPath,
		[parameter(Mandatory = $true)]
		$VHDSize,
		[parameter(Mandatory = $true)]
		$StartUpMemSize
	
		
		
	)
	
	# Configure Hyper-V Virtual Switch if required - Otherwise use an existing Switch 
	
	if ($createnewswitch -eq $true)
	{
		
		New-VMSwitch -Name $SwitchName -SwitchType $SwitchType
		
	}
	
	
	
	# Create Virtual Machine
	
	
	New-VM -Name $VMName -path $VMLocation -SwitchName $SwitchName
	
	New-VHD -Path $VHDPath -Dynamic -SizeBytes $VHDSize
	
	Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath
	
	Get-Vm -Name $VMName | Set-VMMemory -StartupBytes $StartupMemSize
	
}


Export-ModuleMember `
		New-HyperVMachine