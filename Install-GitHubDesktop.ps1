# Install-GitHubDesktop.ps1

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
function Install-GitHubDesktop {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'GitHubDesktop.exe')
    Write-Host 'Downloading GitHub Desktop...'
    Invoke-WebRequest -Uri 'https://desktop.githubusercontent.com/github-desktop/releases/3.4.2-27793d93/GitHubDesktopSetup-x64.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing GitHub Desktop...'
    Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-GitHubDesktop function
Install-GitHubDesktop
