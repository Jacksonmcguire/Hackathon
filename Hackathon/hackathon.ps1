
function Write-ActionLog {
    param (
        [string]$AppName,
        [string]$Action,
        [string]$Copied
    )
    $date = Get-Date

    
    if (-Not ($AppName -eq ''))
    {
        Write-Host "$AppName has been succesfully Installed at $date."
    } elseif (-Not ($Copied -eq '')) {
        Write-Host "$Copied has been succesfully copied to the logging directory at $date."
    } else {
        Write-Host "$Action has been succesfully disabled at $date."
    }
}

function Disable-Protocols {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Protocol
    )
    New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Server" -Force
    New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Client" -Force
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Server" -name 'Enabled' -value '0' -PropertyType 'DWORD'
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Server" -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Client" -name 'Enabled' -value '0' -PropertyType 'DWORD'
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Client" -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'

    Write-ActionLog -Action $Protocol
}

function Disable-TLS-SSL {
    Disable-Protocols -Protocol "TLS 1.0"
    Disable-Protocols -Protocol "TLS 1.1"
    Disable-Protocols -Protocol "SSL 3.0"
}


mkdir -path .\logs
mkdir -path .\installs

function Install-Apps {
    param(
    [string]$Installer,

    [Parameter(Mandatory=$true)]
    [string]$App,
  
    [string]$Link
    )

    if ($App -eq "Edge") {
        Start-Process -FilePath ".\Browsers\MicrosoftEdgeSetup.exe" -RedirectStandardOutput ".\logs\$App.log" -PassThru -Wait
    } elseif ($App -eq "Chrome") {
        Invoke-WebRequest $Link -OutFile ".\installs\$Installer.exe"
        Start-Process -FilePath ".\installs\$Installer.exe" -RedirectStandardOutput ".\logs\$app.log" -PassThru -Wait
    } else {
        Invoke-WebRequest $Link -OutFile ".\installs\$Installer.exe"
        Start-Process -FilePath ".\installs\$Installer.exe" -Argument "/silent" -RedirectStandardOutput ".\logs\$app.log" -PassThru -Wait
    }
    
    Write-ActionLog -AppName $App
}

function Disable-NetBios-IPv6 {

    $AdapterConfigs = Get-WmiObject win32_networkadapterconfiguration
    
    Foreach ($config in $AdapterConfigs) {
    $config.settcpipnetbios(2)
    }
    Write-ActionLog -Action "NetBios"

    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6
    Write-ActionLog -Action "IPv6" 

}


Install-Apps -Installer "ChromeSetup" -App "Chrome" -Link "http://dl.google.com/chrome/install/375.126/chrome_installer.exe"

Install-Apps -Installer "npp.8.4.2.Installer.x64" -App "NotePad++" -Link "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.2/npp.8.4.2.Installer.x64.exe"

Install-Apps -App "Edge"


Disable-TLS-SSL

Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -Remove
Write-ActionLog -Action "Powershell 2.0 Engine"

Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -Remove
Write-ActionLog -Action "SMB1"

Disable-NetBios-IPv6