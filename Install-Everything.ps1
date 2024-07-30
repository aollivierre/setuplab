# Install-Everything.ps1

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
function Install-Everything {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Everything.exe')
    Write-Host 'Downloading Everything...'
    Invoke-WebRequest -Uri 'https://www.voidtools.com/Everything-1.4.1.1024.x64-Setup.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing Everything...'
    Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Everything function
Install-Everything
