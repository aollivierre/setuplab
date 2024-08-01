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

    Write-Host 'Fetching latest GitHub Desktop deployment...'
    $html = Invoke-WebRequest -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32' -Headers @{ 'User-Agent' = 'PowerShell' }
    $downloadUrl = $html.BaseResponse.ResponseUri.AbsoluteUri

    Write-Host "Downloading GitHub Desktop from $downloadUrl..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing GitHub Desktop...'
    Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-GitHubDesktop function
Install-GitHubDesktop
