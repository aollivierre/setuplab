# Check for Unicode symbols in the new web launcher
$file = "C:\code\setuplab\SetupLab-WebLauncher-NoCache-Final.ps1"
$content = Get-Content $file -Raw
$lines = $content -split "`r?`n"

Write-Host "Checking $file for Unicode characters..." -ForegroundColor Yellow

$foundUnicode = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $chars = $line.ToCharArray()
    
    for ($j = 0; $j -lt $chars.Length; $j++) {
        $charCode = [int]$chars[$j]
        
        # Check for non-ASCII characters
        if ($charCode -gt 127) {
            $foundUnicode = $true
            Write-Host "Line $($i+1), Position $($j+1): Unicode character found!" -ForegroundColor Red
            Write-Host "  Character: '$($chars[$j])' (Code: $charCode)" -ForegroundColor Yellow
            Write-Host "  Line content: $line" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

if (-not $foundUnicode) {
    Write-Host "`nNo Unicode characters found! File is 100% ASCII." -ForegroundColor Green
} else {
    Write-Host "`nUnicode characters were found in the file!" -ForegroundColor Red
}

# Also check for specific problem characters
Write-Host "`nChecking for specific problem characters..." -ForegroundColor Yellow
$problemChars = @{
    "✓" = "Checkmark"
    "✗" = "X mark"
    """ = "Left smart quote"
    """ = "Right smart quote"
    "'" = "Left smart single quote"
    "'" = "Right smart single quote"
}

foreach ($char in $problemChars.Keys) {
    if ($content -like "*$char*") {
        Write-Host "Found $($problemChars[$char]): $char" -ForegroundColor Red
        $foundUnicode = $true
    }
}

if (-not $foundUnicode) {
    Write-Host "No problem characters found." -ForegroundColor Green
}