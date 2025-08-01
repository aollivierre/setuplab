# Simple ASCII check for web launcher
$file = "C:\code\setuplab\SetupLab-WebLauncher-NoCache-Final.ps1"
$content = Get-Content $file -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)

Write-Host "Checking $file for non-ASCII characters..." -ForegroundColor Yellow

$nonAsciiFound = $false
$lineNum = 1
$charPos = 0

for ($i = 0; $i -lt $bytes.Length; $i++) {
    $byte = $bytes[$i]
    
    # Track line numbers
    if ($byte -eq 10) { # newline
        $lineNum++
        $charPos = 0
    } else {
        $charPos++
    }
    
    # Check for non-ASCII
    if ($byte -gt 127) {
        Write-Host "Non-ASCII byte found at line $lineNum, position $charPos : Byte value = $byte" -ForegroundColor Red
        $nonAsciiFound = $true
    }
}

if (-not $nonAsciiFound) {
    Write-Host "`nRESULT: File is 100% ASCII - no Unicode characters found!" -ForegroundColor Green
} else {
    Write-Host "`nRESULT: Non-ASCII characters were found!" -ForegroundColor Red
}

# Also scan for problematic patterns
Write-Host "`nScanning for problematic patterns..." -ForegroundColor Yellow
$patterns = @(
    'checkmark|check mark',
    'x mark',
    'smart quote',
    '[[OK][FAIL]]'
)

foreach ($pattern in $patterns) {
    if ($content -match $pattern) {
        Write-Host "Found pattern: $pattern" -ForegroundColor Yellow
    }
}

Write-Host "`nDone." -ForegroundColor Cyan