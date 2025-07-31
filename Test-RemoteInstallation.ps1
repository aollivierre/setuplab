#Requires -Version 5.1
<#
.SYNOPSIS
    Test script to validate SetupLab installation on remote machine
.DESCRIPTION
    This script can be run directly on the target machine to test installation
    without cross-domain issues
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$SetupLabPath = "C:\Temp\SetupLab",
    
    [Parameter(Mandatory = $false)]
    [switch]$RunActualInstall,
    
    [Parameter(Mandatory = $false)]
    [string[]]$TestSoftware = @("7-Zip", "Git", "Visual Studio Code")
)

# Ensure admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges" -ForegroundColor Red
    exit 1
}

Write-Host "SetupLab Remote Installation Test" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# System Information
Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  Computer Name: $env:COMPUTERNAME"
Write-Host "  Domain: $env:USERDOMAIN"
Write-Host "  Windows Version: $([System.Environment]::OSVersion.Version)"
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "  Current User: $env:USERNAME"
Write-Host ""

# Check prerequisites
Write-Host "Checking Prerequisites:" -ForegroundColor Yellow

# 1. Check execution policy
$execPolicy = Get-ExecutionPolicy -Scope Process
Write-Host "  Execution Policy: $execPolicy $(if ($execPolicy -eq 'Bypass' -or $execPolicy -eq 'Unrestricted') { '[OK]' } else { '[WARNING]' })"

# 2. Check .NET Framework
try {
    $dotNetVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction Stop
    $release = $dotNetVersion.Release
    $version = switch ($release) {
        { $_ -ge 533320 } { "4.8.1" }
        { $_ -ge 528040 } { "4.8" }
        { $_ -ge 461808 } { "4.7.2" }
        { $_ -ge 461308 } { "4.7.1" }
        { $_ -ge 460798 } { "4.7" }
        default { "Unknown" }
    }
    Write-Host "  .NET Framework: $version [OK]"
} catch {
    Write-Host "  .NET Framework: Not found [ERROR]" -ForegroundColor Red
}

# 3. Check Windows Update service
$wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "  Windows Update Service: $($wuService.Status) $(if ($wuService.Status -eq 'Running') { '[OK]' } else { '[WARNING]' })"

# 4. Check available disk space
$systemDrive = Get-PSDrive -Name C
$freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
Write-Host "  Free Disk Space: ${freeSpaceGB}GB $(if ($freeSpaceGB -gt 10) { '[OK]' } else { '[WARNING]' })"

# 5. Check Internet connectivity
Write-Host "  Internet Connectivity: " -NoNewline
try {
    $testConnection = Test-NetConnection -ComputerName "github.com" -Port 443 -WarningAction SilentlyContinue
    if ($testConnection.TcpTestSucceeded) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host "FAILED" -ForegroundColor Red
}

Write-Host ""

# Test software installation checks
Write-Host "Testing Software Detection:" -ForegroundColor Yellow

foreach ($software in $TestSoftware) {
    Write-Host "  Checking $software... " -NoNewline
    
    # Check registry
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $found = $false
    foreach ($path in $registryPaths) {
        $items = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*$software*" }
        if ($items) {
            $found = $true
            break
        }
    }
    
    if ($found) {
        Write-Host "INSTALLED" -ForegroundColor Green
    } else {
        Write-Host "NOT FOUND" -ForegroundColor Yellow
    }
}

Write-Host ""

# Test download capabilities
Write-Host "Testing Download Methods:" -ForegroundColor Yellow

# Test BITS
Write-Host "  BITS Service: " -NoNewline
$bitsService = Get-Service -Name BITS -ErrorAction SilentlyContinue
if ($bitsService -and $bitsService.Status -eq 'Running') {
    Write-Host "AVAILABLE" -ForegroundColor Green
} else {
    Write-Host "NOT AVAILABLE" -ForegroundColor Yellow
}

# Test WebClient
Write-Host "  WebClient: " -NoNewline
try {
    $testUrl = "https://www.example.com"
    $webClient = New-Object System.Net.WebClient
    $null = $webClient.DownloadString($testUrl)
    Write-Host "WORKING" -ForegroundColor Green
} catch {
    Write-Host "FAILED" -ForegroundColor Red
}

# Test Invoke-WebRequest
Write-Host "  Invoke-WebRequest: " -NoNewline
try {
    $null = Invoke-WebRequest -Uri "https://www.example.com" -UseBasicParsing -TimeoutSec 5
    Write-Host "WORKING" -ForegroundColor Green
} catch {
    Write-Host "FAILED" -ForegroundColor Red
}

Write-Host ""

# Check for common issues
Write-Host "Checking Common Issues:" -ForegroundColor Yellow

# 1. Check for pending reboots
$pendingReboot = $false
$rebootKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
)
foreach ($key in $rebootKeys) {
    if (Test-Path $key) {
        $pendingReboot = $true
        break
    }
}
Write-Host "  Pending Reboot: $(if ($pendingReboot) { 'YES [WARNING]' } else { 'NO [OK]' })"

# 2. Check Windows Installer service
$msiService = Get-Service -Name msiserver -ErrorAction SilentlyContinue
Write-Host "  Windows Installer: $($msiService.Status) $(if ($msiService.Status -eq 'Running' -or $msiService.Status -eq 'Stopped') { '[OK]' } else { '[WARNING]' })"

# 3. Check for other installers running
$installerProcesses = Get-Process -Name msiexec, setup, install -ErrorAction SilentlyContinue
Write-Host "  Active Installers: $(if ($installerProcesses) { 'FOUND [WARNING]' } else { 'NONE [OK]' })"

Write-Host ""

if ($RunActualInstall) {
    Write-Host "Running SetupLab Installation Test..." -ForegroundColor Yellow
    
    if (Test-Path $SetupLabPath) {
        Set-Location $SetupLabPath
        
        # Check for required files
        $requiredFiles = @("main.ps1", "SetupLabCore.psm1", "software-config.json")
        $missingFiles = @()
        
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path $file)) {
                $missingFiles += $file
            }
        }
        
        if ($missingFiles.Count -gt 0) {
            Write-Host "Missing required files:" -ForegroundColor Red
            $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        } else {
            Write-Host "All required files found. Starting installation..." -ForegroundColor Green
            Write-Host "Logs will be written to: C:\ProgramData\SetupLab\Logs" -ForegroundColor Cyan
            
            # Run with specific test parameters
            & .\main.ps1 -Software $TestSoftware -SkipValidation
        }
    } else {
        Write-Host "SetupLab path not found: $SetupLabPath" -ForegroundColor Red
        Write-Host "Please copy SetupLab files to this location first." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Test completed. Review the results above for any issues." -ForegroundColor Cyan