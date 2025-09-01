# Test Everything 1.5 Alpha installation configuration
$jsonContent = Get-Content -Path "C:\code\setuplab\software-config.json" -Raw | ConvertFrom-Json

# Find both Everything entries
$everything14 = $jsonContent.software | Where-Object { $_.name -eq "Everything 1.4 (Stable)" }
$everything15 = $jsonContent.software | Where-Object { $_.name -eq "Everything 1.5 (Alpha)" }

Write-Host "Everything 1.4 (Stable) Configuration:" -ForegroundColor Cyan
Write-Host "  Name: $($everything14.name)"
Write-Host "  Enabled: $($everything14.enabled)"
Write-Host "  URL: $($everything14.downloadUrl)"
Write-Host "  Install Path: $($everything14.executablePath)"
Write-Host ""

Write-Host "Everything 1.5 (Alpha) Configuration:" -ForegroundColor Yellow
Write-Host "  Name: $($everything15.name)"
Write-Host "  Enabled: $($everything15.enabled)"
Write-Host "  URL: $($everything15.downloadUrl)"
Write-Host "  Install Path: $($everything15.executablePath)"
Write-Host "  Install Args: $($everything15.installArguments -join ' ')"