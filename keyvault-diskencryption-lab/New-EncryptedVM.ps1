# Author: Christopher Jackson, Logan Rakai
# New-EncryptedVM.ps1
#
# This PowerShell script deploys a new Windows VM and a KeyVault with a KeyEncryptionKey which is uses to encrypt the VM
# Please login to your Azure Environment before running this script.  This script create all new resources
# For more info: https://docs.microsoft.com/en-us/azure/security/azure-security-disk-encryption  

#region Azure Login
Connect-AzAccount 
#endregion 

#region Variables
$ResourceGroupName = "REPLACE_ME"
$VMName = "EncryptWin1"
$Location = "South Central US"
$Subnet1Name = "default"
$VNetName = "Encrypt-VNet"
$InterfaceName = $VMName + "-NIC"
$PublicIPName = $VMName + "-PIP"
$ComputerName = $VMName
$VMSize = "Standard_B2ms"
$username = "student"
$password = "1Cloud_Academy_Labs!"
$StorageName = "castorage" + $ResourceGroupName.replace("-","").replace('cal',"").ToLower()
$StorageType = "Standard_LRS"
$OSDiskName = $VMName + "OSDisk"
$OSPublisherName = "MicrosoftWindowsServer"
$OSOffer = "WindowsServer"
$OSSKu = "2019-Datacenter"
$OSVersion = "latest"
#endregion 

#region VM
############################## Create and Deploy the VM ###############################
# Create storage account
Write-Host "Creating storage account: $StorageName..."
$StorageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -SkuName $StorageType -Location $Location

# Create a Public IP
Write-Host "Creating a Public IP: $PublicIPName..."
$publicIP = New-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic

# Create the VNet
Write-Host "Creating a VNet: $VNetName..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix "192.168.1.0/24"
$VNet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -AddressPrefix "192.168.0.0/16" -Location $Location -Subnet $subnetConfig
$myNIC = New-AzNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $publicip.Id

# Create the VM Credentials
Write-Host "Creating VM Credentials..."
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureStringPwd

# Create the basic VM config
Write-Host "Creating the basic VM config..."
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -ComputerName $ComputerName -Windows -Credential $Credential -ProvisionVMAgent
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $myNIC.Id

# Create OS Disk Uri and attach it to the VM
Write-Host "Creating the OSDisk '$OSDiskName' for the VM..."
$NewOSDiskVhdUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName.ToLower() + "-" + $osDiskName + '.vhd'
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $OSPublisherName -Offer $OSOffer -Skus $OSSKu -Version $OSVersion
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name $osDiskName -VhdUri $NewOSDiskVhdUri -CreateOption FromImage

# Create the VM
Write-Host "Building the VM: $VMName..."
New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
#endregion 

#region KeyVault
############################## Create and Deploy the KeyVault and Keys ###############################
$keyVaultName = $("MyKeyVault1" + "-" + $ResourceGroupName)
$keyEncryptionKeyName = $("MyKey1" + "-" + $ResourceGroupName)

# Create the KeyVault
Write-Host "Creating the KeyVault: $keyVaultName..."
$keyVault = New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName -Sku Standard -Location $Location -EnabledForDiskEncryption;
# Set the permissions required to enable the DiskEncryption Policy
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -EnabledForDiskEncryption
$diskEncryptionKeyVaultUrl = $keyVault.VaultUri
$keyVaultResourceId = $keyVault.ResourceId

# Create the KeyEncryptionKey (KEK)
Write-Host "Creating the KeyEncryptionKey (KEK): $keyEncryptionKeyName..."
$kek = Add-AzKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -Destination Software
$keyEncryptionKeyUrl = $kek.Key.Kid

# Output the values of the KeyVault
Write-Host "KeyVault values that will be needed to enable encryption on the VM" -foregroundcolor Cyan
Write-Host "KeyVault Name: $keyVaultName" -foregroundcolor Cyan
Write-Host "diskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl" -foregroundcolor Cyan
Write-Host "keyVaultResourceId: $keyVaultResourceId" -foregroundcolor Cyan
Write-Host "keyEncryptionKeyURL: $keyEncryptionKeyUrl" -foregroundcolor Cyan
#endregion 

#region Encryption Extension
############################## Deploy the VM Encryption Extension ###############################
# Build the encryption extension
Write-Host "Deploying the VM Encryption Extension..."
Set-AzVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
-DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId `
-VolumeType "OS" `
-KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
-KeyEncryptionKeyVaultId $keyVaultResourceId `
-Force 

Get-AzVMDiskEncryptionStatus -ResourceGroupName $ResourceGroupName -VMName $VMName
#endregion