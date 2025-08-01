# Check if our fix is on GitHub
$url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
$content = Invoke-WebRequest -Uri $url -UseBasicParsing

Write-Host "Checking for our fix in the GitHub version..." -ForegroundColor Yellow
$lines = $content.Content -split "`n"

# Look for our fix
$foundFix = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -like "*if (-not `$currentPath)*") {
        $foundFix = $true
        Write-Host "`nFound our fix at line $($i+1):" -ForegroundColor Green
        Write-Host $lines[$i-1]
        Write-Host $lines[$i] -ForegroundColor Cyan
        Write-Host $lines[$i+1]
        Write-Host $lines[$i+2]
        break
    }
}

if (-not $foundFix) {
    Write-Host "`nFix NOT found in GitHub version!" -ForegroundColor Red
    Write-Host "The main branch doesn't have our fix yet." -ForegroundColor Yellow
}

# Show what's around line 47-50
Write-Host "`n`nShowing lines 46-55 from GitHub:" -ForegroundColor Yellow
for ($i = 45; $i -lt 55 -and $i -lt $lines.Count; $i++) {
    Write-Host ("{0,3}: {1}" -f ($i+1), $lines[$i])
}