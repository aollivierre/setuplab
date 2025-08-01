$remoteComputer = "198.18.1.157"
Write-Host "Testing connectivity to $remoteComputer..." -ForegroundColor Yellow

# Test ping
Write-Host "`nPing test:" -ForegroundColor Cyan
Test-Connection -ComputerName $remoteComputer -Count 2

# Test WinRM port
Write-Host "`nTesting WinRM port 5985:" -ForegroundColor Cyan
Test-NetConnection -ComputerName $remoteComputer -Port 5985 | Select-Object ComputerName, RemotePort, TcpTestSucceeded