# Install-VSCode.ps1


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
function Install-VSCode {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'VSCode.exe')
    Write-Host 'Downloading VS Code...'
    Invoke-WebRequest -Uri 'https://update.code.visualstudio.com/latest/win32-x64/stable' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing VS Code...'
    Start-Process -FilePath $installerPath -ArgumentList '/silent /mergetasks=!runcode' -Wait
    Write-Host 'Installation complete.'
}

# Call the Install-VSCode function
Install-VSCode