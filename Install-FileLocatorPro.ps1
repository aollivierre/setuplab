# Install-FileLocatorPro.ps1


# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate to administrator if not already
if (-not (Test-Admin)) {
    Write-Host "Restarting script with elevated permissions..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
function Install-FileLocatorPro {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'FileLocatorPro.exe')
    Write-Host 'Downloading File Locator Pro...'
    Invoke-WebRequest -Uri 'https://download.mythicsoft.com/flp/3435/filelocator_3435.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing File Locator Pro...'
    Start-Process -FilePath $installerPath -ArgumentList '/VERYSILENT' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-FileLocatorPro function
Install-FileLocatorPro