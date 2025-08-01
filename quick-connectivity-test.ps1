Write-Host "Testing connectivity to 198.18.1.157..." -ForegroundColor Yellow
Test-Connection -ComputerName 198.18.1.157 -Count 2 | Format-Table