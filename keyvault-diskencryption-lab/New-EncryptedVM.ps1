# Author: Christopher Jackson
# 4/5/2017
# New-EncryptedVM.ps1
#
# This PowerShell script creates a new Resource Group where it deploys a new Windows VM, a Keyvault with an AD App and KeyEncryptionKey which is uses to encrypt the VM
# Please login to your Azure Environment before running this script.  This script create all new resources
# For more info: https://docs.microsoft.com/en-us/azure/security/azure-security-disk-encryption  

Add-AzureRmAccount -SubscriptionId "a5aa4093-4fc8-4d40-9706-eca7c19c90fd"

$ResourceGroupName = "EncryptRG"
$VMName = "EncryptWin1"
$Location = "South Central US"
$Subnet1Name = "default"
$VNetName = "Encrypt-VNet"
$InterfaceName = $VMName + "-NIC"
$PublicIPName = $VMName + "-PIP"
$ComputerName = $VMName
$VMSize = "Standard_A1_v2"
$username = "student"
$password = "1Cloud_Academy_Labs!"
$StorageName = "storage" + $VMName.ToLower()
$StorageType = "Standard_LRS"
$OSDiskName = $VMName + "OSDisk"
$OSPublisherName = "MicrosoftWindowsServer"
$OSOffer = "WindowsServer"
$OSSKu = "2012-R2-Datacenter"
$OSVersion = "latest"


# Create the Resource Group
#Write-Host "Creating ResourceGroup: $ResourceGroupName..."
#New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

#region KeyVault
############################## Create and Deploy the KeyVault and Keys ###############################
$keyVaultName = $("MyKeyVault1" + "-" + $ResourceGroupName)
$aadAppName = $("MyApp1" + "-" + $ResourceGroupName)
$aadClientID = ""
$aadClientSecret = ""
$keyEncryptionKeyName = $("MyKey1" + "-" + $ResourceGroupName)

# Create a new AD application
Write-Host "Creating a new AD Application: $aadAppName..."
$identifierUri = [string]::Format("http://localhost:8080/{0}",[Guid]::NewGuid().ToString("N"))
$defaultHomePage = 'http://contoso.com'
$now = [System.DateTime]::Now
$oneYearFromNow = $now.AddYears(1)
$aadClientSecret = [Guid]::NewGuid()
$ADAppPassword = ConvertTo-SecureString -String $aadClientSecret.ToString() -AsPlainText -Force
$ADApp = New-AzureRmADApplication -DisplayName $aadAppName -HomePage $defaultHomePage -IdentifierUris $identifierUri -StartDate $now -EndDate $oneYearFromNow -Password $ADAppPassword
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $ADApp.ApplicationId
$aadClientID = $servicePrincipal.ApplicationId
Write-Host "Successfully created a new AAD Application: $aadAppName with ID: $aadClientID"

# Create the KeyVault
Write-Host "Creating the KeyVault: $keyVaultName..."
$keyVault = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName -Sku Standard -Location $Location;
# Set the permissions to 'all' and Enable the DiskEncryption Policy
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $aadClientID -PermissionsToKeys all -PermissionsToSecrets all
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -EnabledForDiskEncryption
$diskEncryptionKeyVaultUrl = $keyVault.VaultUri
$keyVaultResourceId = $keyVault.ResourceId

# Create the KeyEncryptionKey (KEK)
Write-Host "Creating the KeyEncryptionKey (KEK): $keyEncryptionKeyName..."
$kek = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -Destination Software
$keyEncryptionKeyUrl = $kek.Key.Kid

# Output the values of the KeyVault
Write-Host "KeyVault values that will be needed to enable encryption on the VM" -foregroundcolor Cyan
Write-Host "KeyVault Name: $keyVaultName" -foregroundcolor Cyan
Write-Host "aadClientID: $aadClientID" -foregroundcolor Cyan
Write-Host "aadClientSecret: $aadClientSecret" -foregroundcolor Cyan
Write-Host "diskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl" -foregroundcolor Cyan
Write-Host "keyVaultResourceId: $keyVaultResourceId" -foregroundcolor Cyan
Write-Host "keyEncryptionKeyURL: $keyEncryptionKeyUrl" -foregroundcolor Cyan
#endregion

#region VM
############################## Create and Deploy the VM ###############################
# Create storage account
Write-Host "Creating storage account: $StorageName..."
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -SkuName $StorageType -Location $Location


# Create a Public IP
Write-Host "Creating a Public IP: $PublicIPName..."
$publicIP = New-AzureRmPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic

# Create the VNet
Write-Host "Creating a VNet: $VNetName..."
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix "192.168.1.0/24"
$VNet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -AddressPrefix "192.168.0.0/16" -Location $Location -Subnet $subnetConfig
$myNIC = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $publicip.Id

# Create the VM Credentials
Write-Host "Creating VM Credentials..."
$secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureStringPwd

# Create the basic VM config
Write-Host "Creating the basic VM config..."
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -ComputerName $ComputerName -Windows -Credential $Credential
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $myNIC.Id

# Create OS Disk Uri and attach it to the VM
Write-Host "Creating the OSDisk '$OSDiskName' for the VM..."
$NewOSDiskVhdUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName.ToLower() + "-" + $osDiskName + '.vhd'
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $OSPublisherName -Offer $OSOffer -Skus $OSSKu -Version $OSVersion
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $osDiskName -VhdUri $NewOSDiskVhdUri -CreateOption FromImage

# Create the VM
Write-Host "Building the VM: $VMName..."
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
#endregion

#region Encryption Extension
############################## Deploy the VM Encryption Extension ###############################
# Build the encryption extension
Write-Host "Deploying the VM Encryption Extension..."
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
-AadClientID $aadClientID -AadClientSecret $aadClientSecret `
-DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId `
-VolumeType "OS" `
-KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
-KeyEncryptionKeyVaultId $keyVaultResourceId `
-Force

Get-AzureRmVMDiskEncryptionStatus -ResourceGroupName $ResourceGroupName -VMName $VMName
#endregion
