$lines = Get-Content 'C:\code\setuplab\Download-Sysinternals.ps1'
$line100 = $lines[99]  # Line 100 is index 99
Write-Host "Line 100 content:"
Write-Host $line100
Write-Host "`nHex representation:"
$chars = $line100.ToCharArray()
foreach ($char in $chars) {
    $code = [int]$char
    if ($code -gt 127) {
        Write-Host "Char: '$char' Code: $code (Non-ASCII)" -ForegroundColor Red
    } else {
        Write-Host -NoNewline "$char"
    }
}
Write-Host ""