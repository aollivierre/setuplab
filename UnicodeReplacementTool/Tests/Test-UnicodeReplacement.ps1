<#
.SYNOPSIS
    Test script for Unicode Replacement Tool
.DESCRIPTION
    Validates the Unicode detection and replacement functionality
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testDir = $PSScriptRoot
$rootDir = Split-Path $testDir -Parent

# Import functions
. "$rootDir\Scripts\UnicodeReplacementFunctions.ps1"

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    if ($Passed) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "       $Details" -ForegroundColor Yellow
        }
    }
}

# Test Suite
Write-Host "`n=== Unicode Replacement Tool Test Suite ===" -ForegroundColor Cyan
Write-Host "Starting tests...`n"

$totalTests = 0
$passedTests = 0

# Test 1: Configuration Loading
$totalTests++
try {
    $config = Get-UnicodeReplacementConfig
    $testPassed = $null -ne $config -and $config.replacements -and $config.settings
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "Configuration Loading" -Passed $testPassed
} catch {
    Write-TestResult -TestName "Configuration Loading" -Passed $false -Details $_.Exception.Message
}

# Test 2: Unicode Detection (using hex codes to avoid Unicode in test file)
$totalTests++
try {
    # Create test text with Unicode characters using char codes
    $checkmark = [char]0x2713  # Check mark
    $warning = [char]0x26A0    # Warning sign
    $arrow = [char]0x2192      # Right arrow
    $testText = "Hello $checkmark World $warning Test $arrow Complete"
    
    $unicodeChars = Find-UnicodeCharacters -Text $testText
    $testPassed = $unicodeChars.Count -eq 3
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "Unicode Detection" -Passed $testPassed -Details "Found $($unicodeChars.Count) Unicode characters"
} catch {
    Write-TestResult -TestName "Unicode Detection" -Passed $false -Details $_.Exception.Message
}

# Test 3: Character Replacement
$totalTests++
try {
    $checkmark = [char]0x2713
    $testText = "Status: $checkmark"
    $result = Replace-UnicodeInText -Text $testText
    $testPassed = $result.ModifiedText -eq "Status: [OK]"
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "Character Replacement" -Passed $testPassed -Details "Result: $($result.ModifiedText)"
} catch {
    Write-TestResult -TestName "Character Replacement" -Passed $false -Details $_.Exception.Message
}

# Test 4: Multiple Replacements
$totalTests++
try {
    $check = [char]0x2713    # Check mark
    $cross = [char]0x2717    # Cross mark
    $warn = [char]0x26A0     # Warning
    $testText = "$check Success, $cross Failed, $warn Warning"
    $result = Replace-UnicodeInText -Text $testText
    $expected = "[OK] Success, [ERROR] Failed, [WARNING] Warning"
    $testPassed = $result.ModifiedText -eq $expected
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "Multiple Replacements" -Passed $testPassed
} catch {
    Write-TestResult -TestName "Multiple Replacements" -Passed $false -Details $_.Exception.Message
}

# Test 5: Preview Mode
$totalTests++
try {
    $arrow = [char]0x2192
    $testText = "Test $arrow Complete"
    $result = Replace-UnicodeInText -Text $testText -PreviewOnly
    $testPassed = $result.OriginalText -eq $result.ModifiedText -and $result.ReplacementCount -eq 1
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "Preview Mode" -Passed $testPassed
} catch {
    Write-TestResult -TestName "Preview Mode" -Passed $false -Details $_.Exception.Message
}

# Test 6: File Processing (using sample file)
$totalTests++
try {
    # Use the .txt sample file and process it as a .ps1
    $sampleFile = "$rootDir\Samples\Sample-WithUnicode.txt"
    if (Test-Path $sampleFile) {
        # Create a temp .ps1 copy for testing
        $tempFile = "$testDir\temp_test_file.ps1"
        Copy-Item $sampleFile $tempFile -Force
        
        $result = Process-ScriptFile -FilePath $tempFile -PreviewOnly -Force
        $testPassed = $result.Status -eq "PreviewOnly" -and $result.ReplacementCount -gt 0
        if ($testPassed) { $passedTests++ }
        Write-TestResult -TestName "File Processing" -Passed $testPassed -Details "$($result.ReplacementCount) replacements found"
        
        # Cleanup
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-TestResult -TestName "File Processing" -Passed $false -Details "Sample file not found"
    }
} catch {
    Write-TestResult -TestName "File Processing" -Passed $false -Details $_.Exception.Message
}

# Test 7: ASCII Text (should not modify)
$totalTests++
try {
    $asciiText = "This is pure ASCII text with no Unicode characters!"
    $result = Replace-UnicodeInText -Text $asciiText
    $testPassed = $result.OriginalText -eq $result.ModifiedText -and $result.ReplacementCount -eq 0
    if ($testPassed) { $passedTests++ }
    Write-TestResult -TestName "ASCII Text Preservation" -Passed $testPassed
} catch {
    Write-TestResult -TestName "ASCII Text Preservation" -Passed $false -Details $_.Exception.Message
}

# Test 8: Edge Cases
$totalTests++
try {
    $arrow = [char]0x2192
    $edgeCases = @(
        @{ Text = ""; Expected = "" },
        @{ Text = "$arrow"; Expected = "->" },
        @{ Text = "$arrow$arrow$arrow"; Expected = "->->->" },
        @{ Text = "Test$($arrow)Middle$($arrow)End"; Expected = "Test->Middle->End" }
    )
    
    $allPassed = $true
    foreach ($case in $edgeCases) {
        $result = Replace-UnicodeInText -Text $case.Text
        if ($result.ModifiedText -ne $case.Expected) {
            $allPassed = $false
            break
        }
    }
    
    if ($allPassed) { $passedTests++ }
    Write-TestResult -TestName "Edge Cases" -Passed $allPassed
} catch {
    Write-TestResult -TestName "Edge Cases" -Passed $false -Details $_.Exception.Message
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $totalTests"
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 2))%"

if ($passedTests -eq $totalTests) {
    Write-Host "`n[SUCCESS] All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[FAILURE] Some tests failed!" -ForegroundColor Red
    exit 1
}