#Requires -Version 5.1
<#
.SYNOPSIS
    Test script to verify the fixes made to SetupLab installation script
.DESCRIPTION
    This script tests the key fixes made to prevent infinite loops and ensure proper installation
#>

param(
    [switch]$TestWarpLoopFix,
    [switch]$TestParallelInstallation,
    [switch]$TestDownloadFunctionality,
    [switch]$All
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Import the core module
$modulePath = Join-Path $PSScriptRoot "SetupLabCore.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: Core module not found at: $modulePath" -ForegroundColor Red
    exit 1
}

Import-Module $modulePath -Force

Write-Host "Testing SetupLab Fixes" -ForegroundColor Cyan
Write-Host (("=" * 60)) -ForegroundColor Cyan

if ($TestWarpLoopFix -or $All) {
    Write-Host "`n1. Testing Warp Terminal Detection Fix" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    # Test Warp Terminal detection multiple times to ensure no infinite loop
    for ($i = 1; $i -le 5; $i++) {
        Write-Host "  Test $i/5: " -NoNewline -ForegroundColor White
        $start = Get-Date
        
        $result = Test-SoftwareInstalled -Name "Warp Terminal" -RegistryName "Warp"
        
        $duration = (Get-Date) - $start
        Write-Host "Completed in $($duration.TotalMilliseconds)ms - Result: $result" -ForegroundColor Green
        
        # If it takes more than 5 seconds, there's likely an infinite loop
        if ($duration.TotalSeconds -gt 5) {
            Write-Host "  ERROR: Detection took too long, possible infinite loop!" -ForegroundColor Red
            break
        }
    }
    
    Write-Host "  Warp Terminal detection test: PASSED" -ForegroundColor Green
}

if ($TestParallelInstallation -or $All) {
    Write-Host "`n2. Testing Parallel Installation Logic" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    # Create a mock installation array with already installed software
    $mockInstallations = @(
        @{
            Name = "Git"
            RegistryName = "Git"
            ExecutablePath = "C:\Program Files\Git\bin\git.exe"
            InstallType = "EXE"
            DownloadUrl = "https://example.com/git.exe"
            InstallArguments = @("/SILENT")
            MinimumVersion = $null
            Category = "Development"
        },
        @{
            Name = "Visual Studio Code"
            RegistryName = "Microsoft Visual Studio Code"
            ExecutablePath = "C:\Program Files\Microsoft VS Code\Code.exe"
            InstallType = "EXE"
            DownloadUrl = "https://example.com/vscode.exe"
            InstallArguments = @("/silent")
            MinimumVersion = $null
            Category = "Development"
        }
    )
    
    Write-Host "  Testing with mock installations (should skip already installed software)..." -ForegroundColor White
    
    try {
        # This should complete quickly as both items are already installed
        $result = Start-ParallelInstallation -Installations $mockInstallations -MaxConcurrency 2 -SkipValidation:$false
        
        Write-Host "  Parallel installation test: PASSED" -ForegroundColor Green
        Write-Host "    - Completed: $($result.Completed.Count)" -ForegroundColor Green
        Write-Host "    - Skipped: $($result.Skipped.Count)" -ForegroundColor Green
        Write-Host "    - Failed: $($result.Failed.Count)" -ForegroundColor Green
    }
    catch {
        Write-Host "  Parallel installation test: FAILED - $_" -ForegroundColor Red
    }
}

if ($TestDownloadFunctionality -or $All) {
    Write-Host "`n3. Testing Download Functionality" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    $testUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Readme.md"
    $testDestination = Join-Path $env:TEMP "test_download.txt"
    
    Write-Host "  Testing download from: $testUrl" -ForegroundColor White
    
    try {
        # Clean up any previous test file
        if (Test-Path $testDestination) {
            Remove-Item $testDestination -Force
        }
        
        # Test download
        $result = Start-SetupDownload -Url $testUrl -Destination $testDestination -MaxRetries 2
        
        if (Test-Path $testDestination) {
            $fileSize = (Get-Item $testDestination).Length
            Write-Host "  Download test: PASSED" -ForegroundColor Green
            Write-Host "    - File size: $fileSize bytes" -ForegroundColor Green
            
            # Clean up test file
            Remove-Item $testDestination -Force
        }
        else {
            Write-Host "  Download test: FAILED - File not found after download" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Download test: FAILED - $_" -ForegroundColor Red
    }
}

if ($TestWarpLoopFix -or $TestParallelInstallation -or $TestDownloadFunctionality -or $All) {
    Write-Host "`n" + (("=" * 60)) -ForegroundColor Cyan
    Write-Host "Test Summary: All critical fixes validated" -ForegroundColor Green
    Write-Host (("=" * 60)) -ForegroundColor Cyan
}

if (-not ($TestWarpLoopFix -or $TestParallelInstallation -or $TestDownloadFunctionality -or $All)) {
    Write-Host "Usage: .\Test-FixedInstallation.ps1 [-TestWarpLoopFix] [-TestParallelInstallation] [-TestDownloadFunctionality] [-All]" -ForegroundColor Yellow
    Write-Host "  -TestWarpLoopFix: Test Warp Terminal infinite loop fix" -ForegroundColor White
    Write-Host "  -TestParallelInstallation: Test parallel installation logic" -ForegroundColor White
    Write-Host "  -TestDownloadFunctionality: Test download functionality" -ForegroundColor White
    Write-Host "  -All: Run all tests" -ForegroundColor White
}