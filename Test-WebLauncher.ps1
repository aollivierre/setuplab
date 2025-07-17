#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for SetupLab Web Launcher
.DESCRIPTION
    This script tests the web launcher functionality by simulating web execution locally
.EXAMPLE
    .\Test-WebLauncher.ps1
    Tests basic functionality
.EXAMPLE
    .\Test-WebLauncher.ps1 -TestListSoftware
    Tests the ListSoftware functionality
#>

[CmdletBinding()]
param(
    [switch]$TestListSoftware,
    [switch]$TestWithParameters,
    [switch]$UseGitHubUrl
)

Write-Host "SetupLab Web Launcher Test Script" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Test 1: Test local execution of web launcher
if (-not $UseGitHubUrl) {
    Write-Host "Test 1: Testing local web launcher execution" -ForegroundColor Yellow
    Write-Host "This simulates what would happen when running from GitHub" -ForegroundColor Gray
    Write-Host ""
    
    $launcherPath = Join-Path $PSScriptRoot "SetupLab-WebLauncher.ps1"
    
    if (-not (Test-Path $launcherPath)) {
        Write-Host "ERROR: SetupLab-WebLauncher.ps1 not found at: $launcherPath" -ForegroundColor Red
        exit 1
    }
    
    # Test basic list functionality
    if ($TestListSoftware) {
        Write-Host "Testing ListSoftware parameter..." -ForegroundColor Green
        & $launcherPath -ListSoftware -BaseUrl "file:///$PSScriptRoot"
    }
    elseif ($TestWithParameters) {
        Write-Host "Testing with parameters (SkipValidation, MaxConcurrency=2)..." -ForegroundColor Green
        Write-Host "NOTE: This will actually try to install software!" -ForegroundColor Red
        Write-Host "Press CTRL+C within 5 seconds to cancel..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        & $launcherPath -SkipValidation -MaxConcurrency 2 -Categories "Development" -BaseUrl "file:///$PSScriptRoot"
    }
    else {
        Write-Host "Testing basic execution (ListSoftware only for safety)..." -ForegroundColor Green
        & $launcherPath -ListSoftware -BaseUrl "file:///$PSScriptRoot"
    }
}
else {
    # Test 2: Test actual GitHub URL execution
    Write-Host "Test 2: Testing actual GitHub URL execution" -ForegroundColor Yellow
    Write-Host "This will download from the actual GitHub repository" -ForegroundColor Gray
    Write-Host ""
    
    $githubUrl = 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'
    
    Write-Host "Testing with GitHub URL: $githubUrl" -ForegroundColor Green
    Write-Host "Executing: & ([scriptblock]::Create((irm '$githubUrl'))) -ListSoftware" -ForegroundColor Gray
    Write-Host ""
    
    try {
        & ([scriptblock]::Create((Invoke-RestMethod -Uri $githubUrl))) -ListSoftware
        Write-Host ""
        Write-Host "SUCCESS: Web launcher executed successfully from GitHub!" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to execute web launcher from GitHub" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Cyan

# Show example commands for manual testing
Write-Host ""
Write-Host "Example commands for manual testing:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. List software (safe):" -ForegroundColor White
Write-Host "   iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1') -ListSoftware" -ForegroundColor Gray
Write-Host ""
Write-Host "2. With parameters:" -ForegroundColor White
Write-Host "   & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -ListSoftware" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Install specific categories:" -ForegroundColor White
Write-Host "   & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -Categories 'Development','Browsers' -SkipValidation" -ForegroundColor Gray