# Find all smart quotes with context
$content = Get-Content 'C:\code\setuplab\Download-Sysinternals.ps1' -Raw
$lines = $content -split "`r?`n"

Write-Host "Checking all lines for smart quotes..."
$smartQuoteLines = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $chars = $line.ToCharArray()
    $hasSmartQuote = $false
    
    for ($j = 0; $j -lt $chars.Length; $j++) {
        $charCode = [int]$chars[$j]
        # Check for all types of smart quotes
        if ($charCode -in @(8216, 8217, 8220, 8221)) {
            $hasSmartQuote = $true
            break
        }
    }
    
    if ($hasSmartQuote) {
        $smartQuoteLines += [PSCustomObject]@{
            LineNumber = $i + 1
            Content = $line
        }
    }
}

if ($smartQuoteLines.Count -gt 0) {
    Write-Host "`nFound smart quotes on the following lines:"
    foreach ($line in $smartQuoteLines) {
        Write-Host "Line $($line.LineNumber): $($line.Content)"
    }
} else {
    Write-Host "No smart quotes found"
}