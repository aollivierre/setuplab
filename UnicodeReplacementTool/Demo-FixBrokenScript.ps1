<#
.SYNOPSIS
    Demonstrates fixing a Unicode-broken PowerShell script
.DESCRIPTION
    Shows how to use the Unicode Replacement Tool to fix scripts that fail due to Unicode
#>

Write-Host "=== Unicode Replacement Tool Demo ===" -ForegroundColor Cyan
Write-Host "This demo shows how to fix PowerShell scripts broken by Unicode characters`n"

# Step 1: Create a broken script
$brokenScriptPath = "$PSScriptRoot\Samples\Demo-Broken.ps1"
$fixedScriptPath = "$PSScriptRoot\Samples\Demo-Fixed.ps1"

Write-Host "Step 1: Creating a script with Unicode characters..." -ForegroundColor Yellow

# Create script content using character codes to avoid Unicode in this file
$check = [char]0x2713     # Check mark
$cross = [char]0x2717     # Cross  
$warning = [char]0x26A0   # Warning
$arrow = [char]0x2192     # Arrow

$brokenScript = @"
# This script will fail in PowerShell 5.1 due to Unicode

Write-Host "Starting process... $arrow" -ForegroundColor Green

`$status = @{
    Success = "$check Ready"
    Failed = "$cross Error"  
    Warning = "$warning Check logs"
}

if (`$true) {
    Write-Host "$check Operation completed!" -ForegroundColor Green
} else {
    Write-Host "$cross Operation failed!" -ForegroundColor Red
}

Write-Host "Progress: 0% $arrow 50% $arrow 100%"
"@

# Save the broken script
Set-Content -Path $brokenScriptPath -Value $brokenScript -Encoding UTF8
Write-Host "[CREATED] $brokenScriptPath`n" -ForegroundColor Green

# Step 2: Try to run it (it will fail)
Write-Host "Step 2: Attempting to run the broken script..." -ForegroundColor Yellow
Write-Host "[EXPECTED] This should fail with Unicode errors:`n" -ForegroundColor DarkGray

try {
    & $brokenScriptPath
} catch {
    Write-Host "[ERROR] Script failed as expected: $_" -ForegroundColor Red
}

# Step 3: Fix it with our tool
Write-Host "`nStep 3: Fixing the script with Unicode Replacement Tool..." -ForegroundColor Yellow

# First preview
Write-Host "`nPreviewing changes:" -ForegroundColor Cyan
& "$PSScriptRoot\Replace-UnicodeInScripts.ps1" -Path $brokenScriptPath -PreviewOnly

# Actually fix it
Write-Host "`nApplying fixes:" -ForegroundColor Cyan
& "$PSScriptRoot\Replace-UnicodeInScripts.ps1" -Path $brokenScriptPath -NoBackup

# Copy to new location for comparison
Copy-Item -Path $brokenScriptPath -Destination $fixedScriptPath -Force

# Step 4: Run the fixed script
Write-Host "`nStep 4: Running the fixed script..." -ForegroundColor Yellow
Write-Host "[SUCCESS] The fixed script now runs without errors:`n" -ForegroundColor Green

& $fixedScriptPath

# Show the difference
Write-Host "`n=== Comparison ===" -ForegroundColor Cyan
Write-Host "Original (with Unicode):" -ForegroundColor Yellow
Write-Host "  $check $arrow [OK] ->"
Write-Host "  $cross $arrow [FAIL] ->"
Write-Host "  $warning $arrow [WARNING] ->"

Write-Host "`nThis demonstrates how the tool converts Unicode to ASCII-safe alternatives!" -ForegroundColor Green
Write-Host "Check the Samples folder to see both versions of the script." -ForegroundColor Gray