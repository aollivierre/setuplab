#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for SetupLab Web Launcher installation functionality
.DESCRIPTION
    This script tests that the web launcher can properly start installation jobs
    without actually installing software (dry run mode)
#>

[CmdletBinding()]
param(
    [switch]$UseGitHubUrl
)

Write-Host "Testing SetupLab Web Launcher Installation Jobs" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# First, let's modify the config to only try one software for testing
$testConfig = @{
    "software" = @(
        @{
            "name" = "Test Software"
            "category" = "Test"
            "enabled" = $true
            "url" = "https://example.com/test.exe"
            "registryName" = "TestSoftware"
            "executablePath" = "C:\NonExistent\test.exe"
            "installType" = "EXE"
            "installArgs" = @("/S")
        }
    )
    "settings" = @{
        "skipValidation" = $true
        "maxConcurrency" = 1
    }
}

# Save test config
$testConfigPath = Join-Path $env:TEMP "test-software-config.json"
$testConfig | ConvertTo-Json -Depth 10 | Set-Content $testConfigPath

Write-Host "Created test configuration at: $testConfigPath" -ForegroundColor Green
Write-Host ""

# Run with test config
$launcherPath = Join-Path $PSScriptRoot "SetupLab-WebLauncher.ps1"

if (-not (Test-Path $launcherPath)) {
    Write-Host "ERROR: SetupLab-WebLauncher.ps1 not found" -ForegroundColor Red
    exit 1
}

Write-Host "Testing with local launcher and test config..." -ForegroundColor Yellow
Write-Host "NOTE: This will attempt to download but fail (expected behavior for test)" -ForegroundColor Gray
Write-Host ""

try {
    # Run with test config - it will try to download the fake URL and fail, which is expected
    & $launcherPath -BaseUrl "file:///$PSScriptRoot" -ConfigFile "test-software-config.json" -SkipValidation
}
catch {
    Write-Host "Expected error occurred: $_" -ForegroundColor Yellow
}
finally {
    # Cleanup
    if (Test-Path $testConfigPath) {
        Remove-Item $testConfigPath -Force
    }
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you saw the installation job start (even if it failed to download)," -ForegroundColor Green
Write-Host "then the module import issue is fixed!" -ForegroundColor Green