# Check for smart quotes in Download-Sysinternals.ps1
$content = Get-Content 'C:\code\setuplab\Download-Sysinternals.ps1' -Raw
$lines = $content -split "`r?`n"
$foundIssues = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $chars = $line.ToCharArray()
    for ($j = 0; $j -lt $chars.Length; $j++) {
        $charCode = [int]$chars[$j]
        # Check for smart quotes
        if ($charCode -eq 8220 -or $charCode -eq 8221 -or $charCode -eq 8216 -or $charCode -eq 8217) {
            Write-Host "Line $($i+1), Position $($j+1): Found smart quote (char code $charCode)"
            $foundIssues = $true
        }
    }
}

if (-not $foundIssues) {
    Write-Host "No smart quotes found - looking for other issues..."
    
    # Check specific problematic lines
    $line124 = $lines[123]
    $line166 = $lines[165]
    
    Write-Host "`nLine 124:"
    Write-Host $line124
    Write-Host "`nLine 166:"
    Write-Host $line166
}