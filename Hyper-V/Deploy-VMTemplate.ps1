
#Creates Virtual Machine based on Hyper-V Template Files
#Renames VHD and VM and sets VM performance accordingly
#Adds to HA Cluster if specified - Run on Hyper-V Cluster node if adding to Failover Cluster 
#Performs Pester Tests to Verify that VM is Configured and Running as Expected 

#Example: .\Deploy-VMTemplate_Updated.ps1 -Name TESTVM01 -VMType Medium -AddtoCluster True

[cmdletbinding(SupportsShouldProcess)] 
 
Param( 
[Parameter(Position=0,Mandatory,HelpMessage="Enter the name of your new virtual machine")] 
[ValidateNotNullOrEmpty()] 
[string]$Name,
[ValidateSet("Small","Medium","Large")] 
[string]$VMType="Medium",
[Parameter(Position=2,Mandatory=$false,HelpMessage="Specify if the VM should be added to a Windows Failover Cluster")] 
[ValidateSet($true,$false)]  
[string]$AddtoCluster

) 

#Set Variables for VM and VHD locations as required
$ClientName = "Bisinella"
$TemplateVMName = "VM_Template"
$TemplatePath = "C:\ClusterStorage\Volume1\Template\VM_Template\Virtual Machines\17D80070-9D7A-4B75-89A5-840FE58BFD74.vmcx"
$VHDPath = "C:\ClusterStorage\Volume1\VHD"
$VMPath = "C:\ClusterStorage\Volume1\VMs"

#Define parameter values based on VM Type 
Switch ($VMType) { 
    "Small" { 
        $MemoryStartup=512MB 
        $ProcCount=1 
        $MemoryMinimum=512MB 
        $MemoryMaximum=4GB 
    } 
    "Medium" { 
        $MemoryStartup=4GB 
        $ProcCount=2 
        $MemoryMinimum=4GB 
        $MemoryMaximum=8GB 
    } 
    "Large" { 
        $MemoryStartup=8GB 
        $ProcCount=4 
        $MemoryMinimum=8GB 
        $MemoryMaximum=16GB 
    } 
} 
#end switch 

#Define a hash table of parameters for Set-VM 
$setParam = @{ 
 ProcessorCount=$ProcCount 
 DynamicMemory=$True 
 MemoryStartUpBytes= $MemoryStartup 
 MemoryMinimumBytes=$MemoryMinimum 
 MemoryMaximumBytes=$MemoryMaximum
 NewVMName=$Name 
 ErrorAction="Stop" 
} 


Write-Host "Creating new $VMType virtual machine from $ClientName Hyper-V Template" 

#Import the VM Template

Import-VM -Path $TemplatePath -Copy -VhdDestinationPath $VHDPath -VirtualMachinePath "$VMPath\$Name" -GenerateNewId

#Rename VHD File and set VM VHD Disk
$vhd = Get-VMHardDiskDrive –VMName $TemplateVMName

$oldName = $vhd.Path

$newName = "$VHDPath\$Name.vhdx"

Rename-Item $oldName $newName

Set-VMHardDiskDrive –VMName $vhd.VMName –Path $newName -ControllerType $vhd.ControllerType -ControllerNumber $vhd.ControllerNumber –ControllerLocation $vhd.ControllerLocation

#Set VM Size (Small, Medium, Large) and Rename VM
$VM = Get-VM -Name $TemplateVMName
$VM | Set-VM @setparam 

#Add VM to Windows Server Cluster Role if specified

if($AddtoCluster) { 

$ClusterName = (Get-Cluster).Name 

Add-ClusterVirtualMachineRole -Cluster $ClusterName -VirtualMachine $Name 

}

#Start Virtual Machine

Start-VM -VM (Get-VM -Name $Name) -Verbose



#Pester Tests to verify VM Configuration

$VM = Get-VM -Name $Name

$VMConfig = @{

ProcessorCount = $ProcCount

DynamicMemoryEnabled = "True"

State = "Running"

Status = "Operating Normally"

IsClustered = "True"

}

#Start Tests

describe 'VM Processor Configuration' { 


It 'VM Processor Count' { 
$VM.ProcessorCount| Should be $VMConfig.ProcessorCount

}
}


describe 'VM Dynamic Memory Configuration' { 


It 'VM Dynamic Memory Enabled' { 
$VM.DynamicMemoryEnabled | Should be $VMConfig.DynamicMemoryEnabled

}
}


describe 'VM State' { 

It 'VM State is Running' { 
$VM.State | Should be $VMConfig.State

}
}


describe 'VM Operational State' { 

It 'VM is Operating Normally' { 
$VM.Status | Should be $VMConfig.Status

}
}

if ($AddtoCluster) { 

describe 'VM Windows Failover Cluster State' { 

It 'VM is part of Failover Cluster' { 
$VM.IsClustered | Should be $VMConfig.IsClustered

}
}

}
