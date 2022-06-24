# This script performs installations of Microsoft Edge, NotePad++, and Google Chrome, as well as disabling various security and network protocols.

# Function that takes in an Action or an AppName, and with that sends a message to the Host explaining that the task has been carried out succesfuly. 
function Write-ActionLog {
    param (
        [string]$AppName,
        [string]$Action
    )
    $date = Get-Date

    
    if (-Not ($AppName -eq ''))
    {
        Write-Host "$AppName has been succesfully Installed at $date."
    } else {
        Write-Host "$Action has been succesfully disabled at $date."
    }
}
# Function that takes in a Protocol Parameter, and with that Protocol, will go into the Systems Security providers protocols and Disable that Protocol at the Client and Server Level if the files are already present, otherwise it will create those files with Disabled Values.
function Disable-Protocols {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Protocol
    )
    $Server = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Server"
    $Client = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\PROTOCOLS\$Protocol\Client"
    $ServerExists = Test-Path -Path $Server
    $ClientExists = Test-Path -Path $Client
    if (!(($ServerExists -eq $True) -and ($ClientExists -eq $True))) {
        New-Item $Server -Force
        New-Item $Client -Force
        New-ItemProperty -Path $Server -name 'Enabled' -value '0' -PropertyType 'DWORD'
        New-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'
        New-ItemProperty -Path $Server -name 'Enabled' -value '0' -PropertyType 'DWORD'
        New-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'
    } elseif (!($ServerExists -eq $True)) {
        New-Item $Server -Force
        New-ItemProperty -Path $Server -name 'Enabled' -value '0' -PropertyType 'DWORD'
        New-ItemProperty -Path $Server -name 'Enabled' -value '0' -PropertyType 'DWORD'
    } elseif (!($ClientExists -eq $True)) {
        New-Item $Client -Force
        New-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'
        New-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1' -PropertyType 'DWORD'
    } else {
        Set-ItemProperty -Path $Server -name 'Enabled' -value '0'
        Set-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1'
        Set-ItemProperty -Path $Server -name 'Enabled' -value '0'
        Set-ItemProperty -Path $Client -Name 'DisabledByDefault' -value '1'
    }

    Write-ActionLog -Action $Protocol
}
# Function to Invoke the Disable-Protocols function for all Protocols
function Disable-TLS-SSL {
    Disable-Protocols -Protocol "TLS 1.0"
    Disable-Protocols -Protocol "TLS 1.1"
    Disable-Protocols -Protocol "SSL 3.0"
}

mkdir -path C:\Windows\Logs\ProgramData
mkdir -path .\installs
# Function that takes in an App Name, optional Installer and optional Link parameters, and goes through and downloads the installer from the link given, executes that installer and saves the installation logs to. 
function Install-Apps {
    param(
    [string]$Installer,

    [Parameter(Mandatory=$true)]
    [string]$App,
  
    [string]$Link
    )

    if ($App -eq "Edge") {
        Start-Process -FilePath ".\Browsers\MicrosoftEdgeSetup.exe" -RedirectStandardOutput "C:\Windows\Logs\ProgramData\$App.log" -PassThru -Wait
    } elseif ($App -eq "Chrome") {
        Invoke-WebRequest $Link -OutFile ".\installs\$Installer.exe"
        Start-Process -FilePath ".\installs\$Installer.exe" -RedirectStandardOutput "C:\Windows\Logs\ProgramData\$app.log" -PassThru -Wait
    } else {
        Invoke-WebRequest $Link -OutFile ".\installs\$Installer.exe"
        Start-Process -FilePath ".\installs\$Installer.exe" -Argument "/silent" -RedirectStandardOutput "C:\Windows\Logs\ProgramData\$app.log" -PassThru -Wait
    }
    
    Write-ActionLog -AppName $App
}
# Grabs All of the network adapter configurations, and iterates through them, disabling NetBios on each. Also Disables all IPv6 protocols.
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
Remove-Item .\installs