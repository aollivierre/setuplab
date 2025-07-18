#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures Windows Terminal with custom profile and downloads Sysinternals tools
.DESCRIPTION
    This script:
    1. Copies custom Windows Terminal settings.json to user profile
    2. Creates directory structure for LaunchPowerShellAsSystem.ps1
    3. Downloads and extracts Sysinternals Suite
.EXAMPLE
    .\Configure-WindowsTerminal.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$TerminalScriptPath = "C:\code\Terminal\WindowsPowerShellAsSYSTEM"
$SysinternalsPath = "C:\code\sysinternals"
$SysinternalsUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
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
    Write-ConfigLog "Starting Windows Terminal and Sysinternals configuration..." -Level Success
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
    
    # 3. Download and extract Sysinternals Suite
    Write-ConfigLog "Downloading Sysinternals Suite..." -Level Info
    
    # Create Sysinternals directory
    if (-not (Test-Path $SysinternalsPath)) {
        New-Item -ItemType Directory -Path $SysinternalsPath -Force | Out-Null
        Write-ConfigLog "Created directory: $SysinternalsPath" -Level Success
    }
    
    # Download Sysinternals Suite
    $zipPath = Join-Path $env:TEMP "SysinternalsSuite.zip"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        
        Write-ConfigLog "Downloading from: $SysinternalsUrl" -Level Info
        Invoke-WebRequest -Uri $SysinternalsUrl -OutFile $zipPath -UseBasicParsing
        
        # Extract to Sysinternals directory
        Write-ConfigLog "Extracting Sysinternals tools..." -Level Info
        Expand-Archive -Path $zipPath -DestinationPath $SysinternalsPath -Force
        
        # Verify some key tools exist
        $keyTools = @("ProcExp.exe", "ProcMon.exe", "PsExec.exe", "Handle.exe")
        $foundTools = 0
        
        foreach ($tool in $keyTools) {
            if (Test-Path (Join-Path $SysinternalsPath $tool)) {
                $foundTools++
            }
        }
        
        if ($foundTools -gt 0) {
            Write-ConfigLog "Sysinternals Suite extracted successfully ($foundTools key tools verified)" -Level Success
            
            # Add to PATH if not already there
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$SysinternalsPath*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$SysinternalsPath", "Machine")
                Write-ConfigLog "Added Sysinternals to system PATH" -Level Success
            }
        }
        else {
            Write-ConfigLog "Sysinternals extraction may have failed - no key tools found" -Level Warning
        }
        
        # Clean up zip file
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ConfigLog "Failed to download/extract Sysinternals: $_" -Level Error
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
    
    Write-Host "  - Sysinternals Suite: " -NoNewline
    if (Test-Path (Join-Path $SysinternalsPath "PsExec.exe")) {
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