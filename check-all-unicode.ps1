# Check all relevant files for Unicode
$files = @(
    "C:\code\setuplab\SetupLab-WebLauncher-NoCache.ps1",
    "C:\code\setuplab\SetupLab-WebLauncher-NoCache-Final.ps1",
    "C:\code\setuplab\Download-Sysinternals.ps1",
    "C:\code\setuplab\install-claude-cli.ps1"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "`nChecking: $file" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        
        $content = Get-Content $file -Raw
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        
        $nonAsciiFound = $false
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -gt 127) {
                $nonAsciiFound = $true
                break
            }
        }
        
        if (-not $nonAsciiFound) {
            Write-Host "RESULT: 100% ASCII" -ForegroundColor Green
        } else {
            Write-Host "RESULT: Contains Unicode characters!" -ForegroundColor Red
        }
    }
}

Write-Host "`n`nSummary complete." -ForegroundColor Cyan