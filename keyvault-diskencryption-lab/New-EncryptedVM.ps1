# Author: Christopher Jackson, Logan Rakai
# New-EncryptedVM.ps1
#
# This PowerShell script creates a new Resource Group where it deploys a new Windows VM, a Keyvault with an AD App and KeyEncryptionKey which is uses to encrypt the VM
# Please login to your Azure Environment before running this script.  This script create all new resources
# For more info: https://docs.microsoft.com/en-us/azure/security/azure-security-disk-encryption  

Add-AzAccount -SubscriptionId "b197ebe7-8059-4dbe-90a8-15f7bf3d746f" 

$ResourceGroupName = "cal-930-16"
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


# Create the Resource Group
#Write-Host "Creating ResourceGroup: $ResourceGroupName..."
#New-AzResourceGroup -Name $ResourceGroupName -Location $Location

#region KeyVault
############################## Create and Deploy the KeyVault and Keys ###############################
$keyVaultName = $("MyKeyVault1" + "-" + $ResourceGroupName)
$aadAppName = $("MyApp1" + "-" + $ResourceGroupName)
$aadClientID = ""
$aadClientSecret = ""
$keyEncryptionKeyName = $("MyKey1" + "-" + $ResourceGroupName)

# Create a new AD application
Write-Host "Creating a new AD Application: $aadAppName..."
$now = [System.DateTime]::Now
$oneYearFromNow = $now.AddYears(1)
$ADApp =  New-AzADApplication -DisplayName $aadAppName -StartDate $now -EndDate $oneYearFromNow
$credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential" -Property @{'DisplayName' = 'labPassword';}
$appCredential = New-AzADAppCredential -ObjectId $ADapp.Id
$aadClientSecret = $appCredential.SecretText
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $ADApp.AppId
$aadClientID = $servicePrincipal.AppId
Write-Host "Successfully created a new AAD Application: $aadAppName with ID: $aadClientID"


# Create the KeyVault
Write-Host "Creating the KeyVault: $keyVaultName..."
$keyVault = New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName -Sku Standard -Location $Location -EnabledForDiskEncryption;
# Set the permissions required to enable the DiskEncryption Policy
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $aadClientID `
   -PermissionsToKeys get,list,encrypt,decrypt,create,import,sign,verify,wrapKey,unwrapKey `
   -PermissionsToSecrets get,list,set
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

#region Encryption Extension
############################## Deploy the VM Encryption Extension ###############################
# Build the encryption extension
Write-Host "Deploying the VM Encryption Extension..."
Set-AzVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName `
-AadClientID $aadClientID -AadClientSecret $aadClientSecret `
-DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId `
-VolumeType "OS" `
-KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
-KeyEncryptionKeyVaultId $keyVaultResourceId `
-Force 

Get-AzVMDiskEncryptionStatus -ResourceGroupName $ResourceGroupName -VMName $VMName
#endregion
