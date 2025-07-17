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
    
    Request-AdminElevation -ScriptPath $PSCommandPath -Parameters $elevationParams
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

#region Enable Windows Features
Write-SetupLog "" -Level Info
Write-SetupLog "Checking Windows features..." -Level Info

# Enable Remote Desktop if requested
$rdpSoftware = $allSoftware | Where-Object { $_.name -eq "Remote Desktop" }
if ($rdpSoftware) {
    Write-SetupLog "Enabling Remote Desktop..." -Level Info
    try {
        # Enable Remote Desktop
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-SetupLog "Remote Desktop enabled successfully" -Level Success
        
        # Remove from installation list as it's not a software install
        $allSoftware = $allSoftware | Where-Object { $_.name -ne "Remote Desktop" }
    }
    catch {
        Write-SetupLog "Failed to enable Remote Desktop: $_" -Level Error
    }
}
#endregion

#region Parallel Installation
Write-SetupLog "" -Level Info
Write-SetupLog "Starting parallel installation process..." -Level Info

$installationResult = Start-ParallelInstallation -Installations $allSoftware -MaxConcurrency $MaxConcurrency -SkipValidation:$SkipValidation

# Detailed results
if ($installationResult.Failed.Count -gt 0) {
    Write-SetupLog "" -Level Info
    Write-SetupLog "Failed installations:" -Level Error
    foreach ($failed in $installationResult.Failed) {
        Write-SetupLog "  - $($failed.name)" -Level Error
    }
}
#endregion

#region Windows Theme Configuration
$themePath = Join-Path $PSScriptRoot "DarkTheme"
if ((Test-Path $themePath) -and $installationResult.Completed.Count -gt 0) {
    Write-SetupLog "" -Level Info
    $response = Read-Host "Would you like to apply Windows Dark Theme? (Y/N)"
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        try {
            Write-SetupLog "Applying Windows Dark Theme..." -Level Info
            
            $themeScript = Get-ChildItem -Path $themePath -Filter "*.ps1" | Select-Object -First 1
            if ($themeScript) {
                & $themeScript.FullName
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
$summaryPath = Join-Path $PSScriptRoot "Logs" "SetupSummary_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
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

$summary | Out-File -FilePath $summaryPath -Encoding UTF8
Write-SetupLog "Summary report saved to: $summaryPath" -Level Info
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

# Keep window open if running in a new process
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}