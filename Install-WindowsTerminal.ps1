# Install-WindowsTerminal.ps1

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

# Function to install the latest Windows Terminal
function Install-WindowsTerminal {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # URL for the Windows Terminal ZIP
    $url = "https://github.com/microsoft/terminal/releases/download/v1.20.11781.0/Microsoft.WindowsTerminal_1.20.11781.0_x64.zip"

    Write-Host "Downloading Windows Terminal from $url"

    # Define the destination paths
    $zipPath = "$env:TEMP\WindowsTerminal.zip"
    $extractPath = "$env:TEMP\WindowsTerminal"

    # Download the file using BITS
    Start-BitsTransfer -Source $url -Destination $zipPath -Description "Downloading Windows Terminal ZIP"

    Write-Host "Extracting Windows Terminal..."

    # Extract the ZIP file
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    Write-Host "Installation complete."

    # Define the path to the executable
    $exePath = "$extractPath\terminal-1.20.11781.0\windowsterminal.exe"

    # Create a shortcut on the desktop
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = "$desktopPath\Windows Terminal.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath
    $shortcut.Save()
    Write-Host 'Shortcut created on the desktop.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-WindowsTerminal function
Install-WindowsTerminal
