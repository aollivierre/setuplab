#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures Windows Terminal with custom profile
.DESCRIPTION
    This script:
    1. Copies custom Windows Terminal settings.json to user profile
    2. Creates directory structure for LaunchPowerShellAsSystem.ps1
    3. Copies LaunchPowerShellAsSystem.ps1 to the required location
.EXAMPLE
    .\Configure-WindowsTerminal.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$TerminalScriptPath = "C:\code\Terminal\WindowsPowerShellAsSYSTEM"
#endregion

#region Functions
function Write-ConfigLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}
#endregion

#region Main Script
try {
    Write-ConfigLog "Starting Windows Terminal configuration..." -Level Success
    Write-ConfigLog ("=" * 60)
    
    # 1. Configure Windows Terminal settings
    Write-ConfigLog "Configuring Windows Terminal custom profile..." -Level Info
    
    # Get Windows Terminal settings path
    $localPackagesPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
    $terminalSettingsPath = Join-Path $localPackagesPath "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    # Check if Windows Terminal is installed
    if (Test-Path (Split-Path $terminalSettingsPath -Parent)) {
        # Backup existing settings if they exist
        if (Test-Path $terminalSettingsPath) {
            $backupPath = "$terminalSettingsPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $terminalSettingsPath -Destination $backupPath -Force
            Write-ConfigLog "Backed up existing settings to: $backupPath" -Level Info
        }
        
        # Copy custom settings
        $customSettingsPath = Join-Path $PSScriptRoot "Terminal\settings.json"
        if (Test-Path $customSettingsPath) {
            Copy-Item -Path $customSettingsPath -Destination $terminalSettingsPath -Force
            Write-ConfigLog "Custom Windows Terminal settings applied successfully" -Level Success
        }
        else {
            Write-ConfigLog "Custom settings.json not found at: $customSettingsPath" -Level Warning
        }
    }
    else {
        Write-ConfigLog "Windows Terminal not found. Please install it first." -Level Warning
    }
    
    # 2. Create directory structure and copy LaunchPowerShellAsSystem.ps1
    Write-ConfigLog "Setting up LaunchPowerShellAsSystem script..." -Level Info
    
    # Create directory structure
    if (-not (Test-Path $TerminalScriptPath)) {
        New-Item -ItemType Directory -Path $TerminalScriptPath -Force | Out-Null
        Write-ConfigLog "Created directory: $TerminalScriptPath" -Level Success
    }
    
    # Copy LaunchPowerShellAsSystem.ps1
    $launchScriptSource = Join-Path $PSScriptRoot "Terminal\LaunchPowerShellAsSystem.ps1"
    $launchScriptDest = Join-Path $TerminalScriptPath "LaunchPowerShellAsSystem.ps1"
    
    if (Test-Path $launchScriptSource) {
        Copy-Item -Path $launchScriptSource -Destination $launchScriptDest -Force
        Write-ConfigLog "LaunchPowerShellAsSystem.ps1 copied to: $launchScriptDest" -Level Success
    }
    else {
        Write-ConfigLog "LaunchPowerShellAsSystem.ps1 not found at: $launchScriptSource" -Level Warning
    }
    
    Write-ConfigLog ("=" * 60)
    Write-ConfigLog "Configuration completed!" -Level Success
    
    # Show summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  - Windows Terminal custom profile: " -NoNewline
    if (Test-Path $terminalSettingsPath) {
        Write-Host "Configured" -ForegroundColor Green
    } else {
        Write-Host "Not configured (Terminal not installed)" -ForegroundColor Yellow
    }
    
    Write-Host "  - LaunchPowerShellAsSystem script: " -NoNewline
    if (Test-Path $launchScriptDest) {
        Write-Host "Installed" -ForegroundColor Green
    } else {
        Write-Host "Not installed" -ForegroundColor Yellow
    }
}
catch {
    Write-ConfigLog "Error occurred: $_" -Level Error
    Write-ConfigLog $_.Exception.Message -Level Error
    exit 1
}
#endregion