#Create IaaS VM and create new Storage Account, Virtual Network, Subnets and NSG

# Variables for common values
$resourceGroup = ""
$location = "australiaeast"
$vmName = ""
$VirtualNetworkName = ""
$VirtualNetworkAddressPrefix = ""
$SubnetName = ""
$SubnetAdressPrefix = ""
$VirtualNetworkAddressPrefix = ""
$NSGName = ""

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

#Create Storage Account 
$newStorageAcctParams = @{
    'Name' = '' ## Must be globally unique and all lowercase
    'ResourceGroupName' = ''
    'Type' = 'Standard_LRS'
    'Location' = 'australiasoutheast'
}

$storageAccount = New-AzureRmStorageAccount @newStorageAcctParams 


# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAdressPrefix


# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $VirtualNetworkName -AddressPrefix $VirtualNetworkAddressPrefix -Subnet $subnetConfig

#Get Virtual Network
#$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName TARNAYLABNETWORK -Name TARNAYLABVNET1

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmName$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name NSGRuleRDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Allow
  

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name $NSGName -SecurityRules $nsgRuleRDP
  
  #$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName TARNAYLABNETWORK -Name NSG-DMZ

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name "$vmName-NIC" -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[1].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id


#$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName TARNAYLABSTORAGE -Name tarnaylabstorage462

#Set Os Disk Details
$osDiskName = 'OSDisk'
$osDiskUri = $storageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $osDiskName + ".vhd"

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize Standard_A2 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Set-AzureRmVMOSDisk -Name $osDiskName -VhdUri $osDiskUri -CreateOption FromImage | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig -Verbose

