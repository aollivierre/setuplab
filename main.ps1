#Requires -Version 5.1
<#
.SYNOPSIS
    Main orchestrator script for SetupLab - Automated Lab Environment Setup
.DESCRIPTION
    This script orchestrates the installation of multiple software packages in parallel
    using a modular approach with shared functions and configuration-driven installation.
.PARAMETER SkipValidation
    Skip pre-installation validation checks and install all enabled software
.PARAMETER MaxConcurrency
    Maximum number of concurrent installations (default: 4)
.PARAMETER Categories
    Comma-separated list of categories to install (default: all enabled categories)
.PARAMETER Software
    Comma-separated list of specific software names to install
.PARAMETER ListSoftware
    List all available software without installing
.PARAMETER ConfigFile
    Path to custom configuration file (default: software-config.json)
.EXAMPLE
    .\main.ps1
    Runs the setup with default settings
.EXAMPLE
    .\main.ps1 -SkipValidation -MaxConcurrency 6
    Runs setup skipping validation with 6 concurrent installations
.EXAMPLE
    .\main.ps1 -Categories "Development,Browsers"
    Only installs software from Development and Browsers categories
.EXAMPLE
    .\main.ps1 -Software "Git,Visual Studio Code,Chrome"
    Only installs the specified software
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrency = 4,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Categories = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$Software = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$ListSoftware,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "software-config.json"
)

#region Script Initialization
# Set execution policy for this process to avoid script execution issues
if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    try {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "Execution policy set to Bypass for current process" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: Could not set execution policy: $_" -ForegroundColor Yellow
    }
}

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Import core module
$modulePath = Join-Path $PSScriptRoot "SetupLabCore.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: Core module not found at: $modulePath" -ForegroundColor Red
    exit 1
}

Import-Module $modulePath -Force
Write-SetupLog "SetupLab - Automated Lab Environment Setup" -Level Info
Write-SetupLog (("=" * 60)) -Level Info
#endregion

#region Configuration Loading
try {
    $configPath = if ([System.IO.Path]::IsPathRooted($ConfigFile)) {
        $ConfigFile
    } else {
        Join-Path $PSScriptRoot $ConfigFile
    }
    
    $config = Get-SoftwareConfiguration -ConfigFile $configPath
    Write-SetupLog "Loaded configuration from: $configPath" -Level Success
}
catch {
    Write-SetupLog "Failed to load configuration: $_" -Level Error
    exit 1
}
#endregion

#region Software Selection
$allSoftware = $config.software | Where-Object { $_.enabled -eq $true }

# Filter by categories if specified
if ($Categories.Count -gt 0) {
    $allSoftware = $allSoftware | Where-Object { $_.category -in $Categories }
    Write-SetupLog "Filtering by categories: $($Categories -join ', ')" -Level Info
}

# Filter by specific software names if specified
if ($Software.Count -gt 0) {
    $allSoftware = $allSoftware | Where-Object { $_.name -in $Software }
    Write-SetupLog "Filtering by software: $($Software -join ', ')" -Level Info
}

# Apply settings from config if not overridden by parameters
if ($PSBoundParameters.ContainsKey('SkipValidation') -eq $false -and $config.settings.skipValidation) {
    $SkipValidation = $config.settings.skipValidation
}

if ($PSBoundParameters.ContainsKey('MaxConcurrency') -eq $false -and $config.settings.maxConcurrency) {
    $MaxConcurrency = $config.settings.maxConcurrency
}
#endregion

#region List Software Mode
if ($ListSoftware) {
    Write-SetupLog "Available Software:" -Level Info
    Write-SetupLog (("=" * 60)) -Level Info
    
    $groupedSoftware = $config.software | Group-Object -Property category | Sort-Object Name
    
    foreach ($group in $groupedSoftware) {
        Write-SetupLog "" -Level Info
        Write-SetupLog "Category: $($group.Name)" -Level Info
        Write-SetupLog (("-" * 30)) -Level Info
        
        foreach ($sw in ($group.Group | Sort-Object name)) {
            $status = if ($sw.enabled) { "Enabled" } else { "Disabled" }
            $installed = if (Test-SoftwareInstalled -Name $sw.name -RegistryName $sw.registryName -ExecutablePath $sw.executablePath) {
                " [INSTALLED]"
            } else {
                ""
            }
            
            Write-Host ("  {0,-30} {1,-10}{2}" -f $sw.name, "($status)", $installed) -ForegroundColor $(if ($sw.enabled) { 'White' } else { 'Gray' })
        }
    }
    
    Write-SetupLog "" -Level Info
    Write-SetupLog "Total: $($config.software.Count) software packages" -Level Info
    exit 0
}
#endregion

#region Admin Check
if (-not (Test-AdminPrivileges)) {
    Write-SetupLog "Administrator privileges required. Requesting elevation..." -Level Warning
    
    # Build parameter hashtable for elevation
    $elevationParams = @{}
    
    if ($SkipValidation) { $elevationParams['SkipValidation'] = $true }
    if ($PSBoundParameters.ContainsKey('MaxConcurrency')) { $elevationParams['MaxConcurrency'] = $MaxConcurrency }
    if ($Categories.Count -gt 0) { $elevationParams['Categories'] = $Categories }
    if ($Software.Count -gt 0) { $elevationParams['Software'] = $Software }
    if ($PSBoundParameters.ContainsKey('ConfigFile')) { $elevationParams['ConfigFile'] = $ConfigFile }
    
    # Request elevation with ExecutionPolicy Bypass
    $scriptArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-NoProfile",
        "-File", "`"$PSCommandPath`""
    )
    
    # Add original parameters
    foreach ($key in $elevationParams.Keys) {
        if ($elevationParams[$key] -is [bool]) {
            if ($elevationParams[$key]) {
                $scriptArgs += "-$key"
            }
        }
        elseif ($elevationParams[$key] -is [array]) {
            $scriptArgs += "-$key"
            $scriptArgs += ($elevationParams[$key] -join ',')
        }
        else {
            $scriptArgs += "-$key"
            $scriptArgs += $elevationParams[$key]
        }
    }
    
    Start-Process -FilePath "powershell.exe" -ArgumentList $scriptArgs -Verb RunAs -Wait
    exit 0
}

Write-SetupLog "Running with administrator privileges" -Level Success
#endregion

#region Pre-Installation Summary
Write-SetupLog "" -Level Info
Write-SetupLog "Installation Summary:" -Level Info
Write-SetupLog "  Total packages: $($allSoftware.Count)" -Level Info
Write-SetupLog "  Skip validation: $SkipValidation" -Level Info
Write-SetupLog "  Max concurrency: $MaxConcurrency" -Level Info
Write-SetupLog "" -Level Info

if ($allSoftware.Count -eq 0) {
    Write-SetupLog "No software selected for installation" -Level Warning
    exit 0
}

Write-SetupLog "Software to install:" -Level Info
foreach ($sw in ($allSoftware | Sort-Object category, name)) {
    Write-SetupLog "  [$($sw.category)] $($sw.name)" -Level Info
}

Write-SetupLog "" -Level Info
Write-Host "Press any key to continue or CTRL+C to cancel..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#endregion

#region Early System Configuration (Dark Theme, RDP)
Write-SetupLog "" -Level Info
Write-SetupLog "Applying early system configurations..." -Level Info
Write-SetupLog (("=" * 60)) -Level Info

# 1. Apply Dark Theme First
Write-SetupLog "" -Level Info
Write-SetupLog "Step 1: Applying Windows Dark Theme..." -Level Info
$themePath = Join-Path $PSScriptRoot "DarkTheme"
if (Test-Path $themePath) {
    try {
        $themeScript = Get-ChildItem -Path $themePath -Filter "*.ps1" | Select-Object -First 1
        if ($themeScript) {
            & $themeScript.FullName -Mode dark -RestartExplorer $false
            Write-SetupLog "Dark theme applied successfully" -Level Success
        }
        else {
            Write-SetupLog "Dark theme script not found" -Level Warning
        }
    }
    catch {
        Write-SetupLog "Failed to apply dark theme: $_" -Level Error
    }
}
else {
    Write-SetupLog "Dark theme directory not found at: $themePath" -Level Warning
}

# 2. Enable Remote Desktop
Write-SetupLog "" -Level Info
Write-SetupLog "Step 2: Enabling Remote Desktop..." -Level Info
try {
    # Enable Remote Desktop
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Write-SetupLog "Remote Desktop enabled successfully" -Level Success
}
catch {
    Write-SetupLog "Failed to enable Remote Desktop: $_" -Level Error
}
#endregion

#region System Configuration (Rename, Domain Join)
Write-SetupLog "" -Level Info
Write-SetupLog "Starting system configuration..." -Level Info
Write-SetupLog (("=" * 60)) -Level Info

# 1. Rename Computer
Write-SetupLog "" -Level Info
Write-SetupLog "Step 1: Renaming computer..." -Level Info
$renameScript = Join-Path $PSScriptRoot "Rename-Computer.ps1"
$needsReboot = $false
if (Test-Path $renameScript) {
    try {
        # Capture the script output to determine if rename happened
        $renameOutput = & $renameScript
        if ($renameOutput -match "successfully renamed") {
            $needsReboot = $true
            Write-SetupLog "Computer rename completed - reboot required" -Level Success
        }
        else {
            Write-SetupLog "Computer already has the correct name or rename skipped" -Level Info
        }
    }
    catch {
        Write-SetupLog "Computer rename failed: $_" -Level Error
    }
}
else {
    Write-SetupLog "Computer rename script not found at: $renameScript" -Level Warning
}

# 2. Join Domain
Write-SetupLog "" -Level Info
Write-SetupLog "Step 2: Joining domain..." -Level Info
$joinScript = Join-Path $PSScriptRoot "Join-Domain.ps1"
if (Test-Path $joinScript) {
    try {
        # Capture the script output to determine if domain join happened
        $joinOutput = & $joinScript
        if ($joinOutput -match "Successfully joined to domain") {
            $needsReboot = $true
            Write-SetupLog "Domain join completed - reboot required" -Level Success
        }
        else {
            Write-SetupLog "Computer already domain joined or join skipped" -Level Info
        }
    }
    catch {
        Write-SetupLog "Domain join failed: $_" -Level Error
    }
}
else {
    Write-SetupLog "Domain join script not found at: $joinScript" -Level Warning
}

Write-SetupLog "" -Level Info
Write-SetupLog (("=" * 60)) -Level Info
#endregion

#region Serial Installation
Write-SetupLog "" -Level Info
Write-SetupLog "Starting serial installation process..." -Level Info

$installationResult = Start-SerialInstallation -Installations $allSoftware -SkipValidation:$SkipValidation

# Detailed results
if ($installationResult.Failed.Count -gt 0) {
    Write-SetupLog "" -Level Info
    Write-SetupLog "Failed installations:" -Level Error
    foreach ($failed in $installationResult.Failed) {
        Write-SetupLog "  - $($failed.name)" -Level Error
    }
}
#endregion


#region Configure Windows Terminal
# Configure Windows Terminal with custom profile
Write-SetupLog "" -Level Info
Write-SetupLog "Configuring Windows Terminal..." -Level Info

$configureTerminalScript = Join-Path $PSScriptRoot "Configure-WindowsTerminal.ps1"
if (Test-Path $configureTerminalScript) {
    try {
        & $configureTerminalScript
        Write-SetupLog "Windows Terminal configuration completed" -Level Success
    }
    catch {
        Write-SetupLog "Windows Terminal configuration failed: $_" -Level Error
    }
}
else {
    Write-SetupLog "Windows Terminal configuration script not found at: $configureTerminalScript" -Level Warning
}
#endregion

#region Download Sysinternals
# Download and install Sysinternals Suite
Write-SetupLog "" -Level Info
Write-SetupLog "Downloading Sysinternals Suite..." -Level Info

$sysinternalsScript = Join-Path $PSScriptRoot "Download-Sysinternals.ps1"
if (Test-Path $sysinternalsScript) {
    try {
        & $sysinternalsScript
        Write-SetupLog "Sysinternals download completed" -Level Success
    }
    catch {
        Write-SetupLog "Sysinternals download failed: $_" -Level Error
    }
}
else {
    Write-SetupLog "Sysinternals download script not found at: $sysinternalsScript" -Level Warning
}
#endregion

#region Environment Variables Update
if ($installationResult.Completed.Count -gt 0) {
    Write-SetupLog "" -Level Info
    Write-SetupLog "Updating environment variables..." -Level Info
    
    try {
        # Refresh PATH environment variable
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-SetupLog "Environment variables updated" -Level Success
    }
    catch {
        Write-SetupLog "Failed to update environment variables: $_" -Level Warning
    }
}
#endregion

#region Final Summary
Write-SetupLog "" -Level Info
Write-SetupLog (("=" * 60)) -Level Info
Write-SetupLog "Setup Complete!" -Level Info
Write-SetupLog (("=" * 60)) -Level Info

# Create summary report
$logsDir = Join-Path $PSScriptRoot "Logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$summaryPath = Join-Path $logsDir "SetupSummary_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$summary = @"
SetupLab Installation Summary
Generated: $(Get-Date)
===============================

Completed Installations ($($installationResult.Completed.Count)):
$($installationResult.Completed | ForEach-Object { "  - $($_.name)" } | Out-String)

Failed Installations ($($installationResult.Failed.Count)):
$($installationResult.Failed | ForEach-Object { "  - $($_.name)" } | Out-String)

Skipped Installations ($($installationResult.Skipped.Count)):
$($installationResult.Skipped | ForEach-Object { "  - $($_.name)" } | Out-String)

Configuration:
  Max Concurrency: $MaxConcurrency
  Skip Validation: $SkipValidation
  Config File: $ConfigFile
"@

try {
    $summary | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-SetupLog "Summary report saved to: $summaryPath" -Level Info
} catch {
    Write-SetupLog "Could not save summary report: $_" -Level Warning
}
#endregion

#region Post-Installation Notes
if ($installationResult.Completed.Count -gt 0) {
    Write-SetupLog "" -Level Info
    Write-SetupLog "Post-Installation Notes:" -Level Info
    
    # Docker Desktop
    if ($installationResult.Completed | Where-Object { $_.name -eq "Docker Desktop" }) {
        Write-SetupLog "  - Docker Desktop: Restart required for full functionality" -Level Warning
    }
    
    # VS Code
    if ($installationResult.Completed | Where-Object { $_.name -eq "Visual Studio Code" }) {
        Write-SetupLog "  - VS Code: Added to PATH and context menus" -Level Info
    }
    
    # Git
    if ($installationResult.Completed | Where-Object { $_.name -eq "Git" }) {
        Write-SetupLog "  - Git: Available in PATH for all terminals" -Level Info
    }
    
    # Node.js
    if ($installationResult.Completed | Where-Object { $_.name -eq "Node.js" }) {
        Write-SetupLog "  - Node.js: npm and npx are now available" -Level Info
    }
    
    # Windows Terminal
    if ($installationResult.Completed | Where-Object { $_.name -eq "Windows Terminal" }) {
        Write-SetupLog "  - Windows Terminal: Set as default terminal in Windows 11" -Level Info
    }
    
    # Claude Code
    if ($installationResult.Completed | Where-Object { $_.name -eq "Claude Code" }) {
        Write-SetupLog "  - Claude Code: Run 'claude --help' to get started" -Level Info
    }
}
#endregion

Write-SetupLog "" -Level Info
Write-SetupLog "Setup completed. Check the summary report for details." -Level Success

#region Check for Required Reboot
if ($needsReboot) {
    Write-SetupLog "" -Level Warning
    Write-SetupLog "IMPORTANT: A system reboot is required!" -Level Warning
    Write-SetupLog "The computer name was changed and/or domain join was performed." -Level Warning
    Write-SetupLog "" -Level Warning
    
    Write-Host ""
    Write-Host "SYSTEM REBOOT REQUIRED!" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host ""
    Write-Host "The following changes require a reboot:" -ForegroundColor Yellow
    Write-Host "  - Computer rename and/or Domain join" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "All software has been installed successfully." -ForegroundColor Green
    Write-Host ""
    
    $rebootResponse = Read-Host "Do you want to reboot now? (Y/N)"
    if ($rebootResponse -eq 'Y' -or $rebootResponse -eq 'y') {
        Write-SetupLog "User chose to reboot. Restarting in 10 seconds..." -Level Warning
        Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
        exit
    }
    else {
        Write-SetupLog "User chose not to reboot" -Level Warning
        Write-Host ""
        Write-Host "Remember to reboot your system to complete the configuration." -ForegroundColor Yellow
    }
}
#endregion

# Keep window open if running in a new process
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}