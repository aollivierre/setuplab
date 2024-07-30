# Install-Git.ps1

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
function Install-Git {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Git.exe')
    Write-Host 'Downloading Git...'
    
    try {
        # Attempt to download using Invoke-WebRequest
        Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe' -OutFile $installerPath -ErrorAction Stop
        Write-Host 'Download complete.'
    } catch {
        Write-Host 'Invoke-WebRequest failed, attempting with Start-BitsTransfer...'
        Start-BitsTransfer -Source 'https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe' -Destination $installerPath
        Write-Host 'Download complete using Start-BitsTransfer.'
    }

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing Git...'
    Start-Process -FilePath $installerPath -ArgumentList '/SILENT' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Git function
Install-Git
