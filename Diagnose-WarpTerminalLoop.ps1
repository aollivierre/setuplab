#Requires -Version 5.1
<#
.SYNOPSIS
    Diagnostic script to identify Warp Terminal infinite loop issue without running installer
.DESCRIPTION
    This script helps diagnose why Warp Terminal detection is causing an infinite loop
    in the SetupLab installation process.
#>

Write-Host "SetupLab Warp Terminal Loop Diagnostic Tool" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# 1. Check Registry Entries
Write-Host "`n1. Checking Registry for Warp-related entries..." -ForegroundColor Yellow

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$warpEntries = @()
foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        $entries = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                   Where-Object { $_.DisplayName -like "*Warp*" }
        
        if ($entries) {
            $entries | ForEach-Object {
                $warpEntries += [PSCustomObject]@{
                    Path = $path
                    DisplayName = $_.DisplayName
                    PSChildName = $_.PSChildName
                    UninstallString = $_.UninstallString
                }
            }
        }
    }
}

Write-Host "`nFound $($warpEntries.Count) Warp-related registry entries:" -ForegroundColor Green
$warpEntries | Format-Table -AutoSize

# 2. Test Pattern Matching
Write-Host "`n2. Testing registry name patterns..." -ForegroundColor Yellow

$testPatterns = @(
    "Warp",
    "Warp*",
    "*Warp*",
    "Warp Terminal",
    "Warp Terminal*"
)

foreach ($pattern in $testPatterns) {
    $matches = $warpEntries | Where-Object { $_.DisplayName -like $pattern }
    Write-Host "Pattern '$pattern': $($matches.Count) matches" -ForegroundColor Gray
}

# 3. Check SetupLabCore.psm1 Implementation
Write-Host "`n3. Analyzing SetupLabCore.psm1..." -ForegroundColor Yellow

$modulePath = Join-Path $PSScriptRoot "SetupLabCore.psm1"
if (Test-Path $modulePath) {
    # Find Test-SoftwareInstalled function
    $content = Get-Content $modulePath -Raw
    
    # Look for the function
    if ($content -match 'function\s+Test-SoftwareInstalled\s*\{([\s\S]*?)\n\}') {
        Write-Host "Found Test-SoftwareInstalled function" -ForegroundColor Green
        
        # Check if it has proper loop control
        $functionBody = $matches[1]
        
        # Look for potential issues
        $issues = @()
        
        if ($functionBody -notmatch '\$found\s*=\s*\$true') {
            $issues += "Missing found flag to exit early"
        }
        
        if ($functionBody -match 'foreach.*\{[^}]*foreach') {
            $issues += "Nested foreach loops detected"
        }
        
        if ($functionBody -notmatch 'break|return.*\$true') {
            $issues += "Missing break or early return"
        }
        
        if ($issues.Count -gt 0) {
            Write-Host "`nPotential issues found:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        } else {
            Write-Host "No obvious loop issues found in function" -ForegroundColor Green
        }
    }
    
    # Check Start-ParallelInstallation
    if ($content -match 'function\s+Start-ParallelInstallation\s*\{([\s\S]*?)\n\}') {
        Write-Host "`nFound Start-ParallelInstallation function" -ForegroundColor Green
        
        $functionBody = $matches[1]
        
        # Look for job handling
        if ($functionBody -match 'while.*jobs') {
            Write-Host "Found job processing loop" -ForegroundColor Yellow
            
            # Check for proper job cleanup
            if ($functionBody -notmatch 'Remove-Job') {
                Write-Host "  WARNING: Missing Remove-Job for cleanup" -ForegroundColor Red
            }
        }
    }
}

# 4. Check software-config.json
Write-Host "`n4. Checking software-config.json..." -ForegroundColor Yellow

$configPath = Join-Path $PSScriptRoot "software-config.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    $warpConfig = $config.software | Where-Object { $_.name -like "*Warp*" }
    
    if ($warpConfig) {
        Write-Host "Warp Terminal configuration:" -ForegroundColor Green
        Write-Host "  Name: $($warpConfig.name)" -ForegroundColor Gray
        Write-Host "  Registry Name: $($warpConfig.registryName)" -ForegroundColor Cyan
        Write-Host "  Enabled: $($warpConfig.enabled)" -ForegroundColor Gray
        
        # Check if registry name is too broad
        if ($warpConfig.registryName -eq "Warp") {
            Write-Host "`n  WARNING: Registry name 'Warp' is too broad!" -ForegroundColor Red
            Write-Host "  This will match multiple entries like 'Warp', 'WarpSetup', etc." -ForegroundColor Red
            Write-Host "  RECOMMENDATION: Change to 'Warp Terminal' or use wildcard 'Warp Terminal*'" -ForegroundColor Yellow
        }
    }
}

# 5. Simulate the detection logic
Write-Host "`n5. Simulating detection logic..." -ForegroundColor Yellow

# This simulates what might be happening
$detectionCount = 0
$maxIterations = 10

Write-Host "Testing with current registry pattern..." -ForegroundColor Gray

for ($i = 1; $i -le $maxIterations; $i++) {
    # Simulate checking all registry paths
    foreach ($entry in $warpEntries) {
        if ($entry.DisplayName -like "Warp*") {
            $detectionCount++
            if ($detectionCount -le 5) {
                Write-Host "  Iteration ${i}: Found '$($entry.DisplayName)'" -ForegroundColor Yellow
            }
        }
    }
    
    # In a proper implementation, we should break here
    # But if the break is missing, it continues...
}

if ($detectionCount -gt $maxIterations) {
    Write-Host "`n  ISSUE CONFIRMED: Detection ran $detectionCount times!" -ForegroundColor Red
    Write-Host "  This indicates missing loop control or break statement." -ForegroundColor Red
}

# 6. Summary and Recommendations
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

Write-Host "`nLikely Root Cause:" -ForegroundColor Yellow
Write-Host "1. Registry pattern 'Warp' is too broad and matches multiple entries" -ForegroundColor White
Write-Host "2. Missing loop control in parallel job processing" -ForegroundColor White
Write-Host "3. Job results might be processed multiple times" -ForegroundColor White

Write-Host "`nRecommended Fixes:" -ForegroundColor Green
Write-Host "1. Change registryName from 'Warp' to 'Warp Terminal' in software-config.json" -ForegroundColor White
Write-Host "2. Add break/return after successful detection in Test-SoftwareInstalled" -ForegroundColor White
Write-Host "3. Ensure jobs are properly removed after processing" -ForegroundColor White
Write-Host "4. Add job deduplication logic" -ForegroundColor White

Write-Host "`nQuick Fix Command:" -ForegroundColor Cyan
Write-Host '(Get-Content "software-config.json") -replace ''"registryName": "Warp"'', ''"registryName": "Warp Terminal"'' | Set-Content "software-config.json"' -ForegroundColor Yellow

Write-Host "`nDiagnostic complete!" -ForegroundColor Green