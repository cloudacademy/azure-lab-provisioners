# Disable Windows Defender real-time monitoring
Set-MpPreference -DisableRealtimeMonitoring $true

function Install-AzurePowerShell {
    $ProgressPreference = 'SilentlyContinue'
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    
    # Only install required packages to reduce startup time
    $modules = @("Az.Accounts", "Az.StorageSync", "Az.Storage", "Az.Resources") 
    foreach ($module in $modules) {
        Install-Module -Name $module -Force -AllowClobber -Confirm:$false
    }
}

function Set-LabArtifacts {
    $ProgressPreference = 'SilentlyContinue' # Ignore progress updates (100X speedup)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # GitHub only supports tls 1.2 now (PS use 1.0 by default)
    New-Item -ItemType Directory -Force -Path C:\Users\student\Desktop  # Force directory creation (in case student Desktop isn't created yet)
    Invoke-WebRequest -Uri "https://s3-us-west-2.amazonaws.com/clouda-labs-assets/azure-file-sync/StorageSyncAgent_WS2019.msi" -OutFile "C:\Users\student\Desktop\StorageSyncAgent_WS2019.msi"
    # Create backup
    $path = "C:\Agents"
    if(!(Test-Path $path))
    {
        New-Item -ItemType Directory -Force -Path C:\Agents
    }
    Invoke-WebRequest -Uri "https://s3-us-west-2.amazonaws.com/clouda-labs-assets/azure-file-sync/StorageSyncAgent_WS2019.msi" -OutFile $($path + "\" + "StorageSyncAgent_WS2019.msi")
}

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
    Stop-Process -Name iexplore -Force -ErrorAction SilentlyContinue
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1 -Force
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1 -Force
    Stop-Process -Name iexplore
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}

function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000 -Force
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green
}

# Disable Windows update
Stop-Service -NoWait -displayname "Windows Update"

Set-LabArtifacts
Disable-UserAccessControl
Disable-InternetExplorerESC
Install-AzurePowerShell
