param(
    [string]$RemoteComputer = "198.18.1.157"
)

Write-Host "Testing connection to $RemoteComputer..." -ForegroundColor Yellow

# Test ping
Write-Host "`nPing test:" -ForegroundColor Cyan
Test-Connection -ComputerName $RemoteComputer -Count 2 -ErrorAction SilentlyContinue

# Test WinRM
Write-Host "`nTesting WinRM:" -ForegroundColor Cyan
Test-WSMan -ComputerName $RemoteComputer -ErrorAction SilentlyContinue

# Test with credentials
Write-Host "`nTesting with credentials:" -ForegroundColor Cyan
$securePassword = ConvertTo-SecureString "Default1234" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("xyz\administrator", $securePassword)

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Time = Get-Date
        }
    }
    
    Write-Host "Remote system info:" -ForegroundColor Green
    Write-Host "  Computer: $($result.ComputerName)"
    Write-Host "  User: $($result.UserName)"
    Write-Host "  Time: $($result.Time)"
    
    Remove-PSSession -Session $session
} catch {
    Write-Host "Connection failed: $_" -ForegroundColor Red
}