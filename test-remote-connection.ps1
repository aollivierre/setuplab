# Test Remote Connection to Windows 11 VM
$remoteComputer = "198.18.1.153"
$username = "xyz\administrator"
$password = "Default1234"

# Create credentials
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "Testing connection to $remoteComputer..." -ForegroundColor Yellow

try {
    # Test WinRM connectivity
    $session = New-PSSession -ComputerName $remoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "Successfully connected to $remoteComputer" -ForegroundColor Green
    
    # Get basic system info
    $systemInfo = Invoke-Command -Session $session -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            Domain = $env:USERDOMAIN
            OS = (Get-WmiObject Win32_OperatingSystem).Caption
            PSVersion = $PSVersionTable.PSVersion.ToString()
            CurrentUser = whoami
        }
    }
    
    Write-Host "`nSystem Information:" -ForegroundColor Cyan
    $systemInfo.GetEnumerator() | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
    
    # Clean up
    Remove-PSSession -Session $session
    
    Write-Host "`nConnection test successful!" -ForegroundColor Green
    
} catch {
    Write-Host "Failed to connect: $_" -ForegroundColor Red
    
    # Try to diagnose the issue
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    
    # Test network connectivity
    if (Test-Connection -ComputerName $remoteComputer -Count 1 -Quiet) {
        Write-Host "  - Network connectivity: OK" -ForegroundColor Green
    } else {
        Write-Host "  - Network connectivity: FAILED" -ForegroundColor Red
    }
    
    # Check if WinRM service is listening
    try {
        $tcpTest = Test-NetConnection -ComputerName $remoteComputer -Port 5985 -WarningAction SilentlyContinue
        if ($tcpTest.TcpTestSucceeded) {
            Write-Host "  - WinRM port (5985): OPEN" -ForegroundColor Green
        } else {
            Write-Host "  - WinRM port (5985): CLOSED" -ForegroundColor Red
        }
    } catch {
        Write-Host "  - WinRM port test failed" -ForegroundColor Red
    }
}