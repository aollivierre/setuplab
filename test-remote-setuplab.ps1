# Test Remote Connection to setuplab01.xyz.local
$remoteComputer = "setuplab01.xyz.local"
$remoteIP = "198.18.1.157"
$username = "xyz\administrator"
$password = "Default1234"

# Create credentials
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "Testing connection to $remoteComputer ($remoteIP)..." -ForegroundColor Yellow

# Test DNS resolution
Write-Host "`nDNS Resolution Test:" -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName -Name $remoteComputer -ErrorAction Stop
    Write-Host "  Success: $remoteComputer resolves to $($dnsResult.IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "  Warning: DNS resolution failed, trying IP directly" -ForegroundColor Yellow
}

# Test network connectivity
Write-Host "`nNetwork Connectivity Test:" -ForegroundColor Yellow
$pingResult = Test-Connection -ComputerName $remoteIP -Count 2 -Quiet
if ($pingResult) {
    Write-Host "  Success: Can ping $remoteIP" -ForegroundColor Green
} else {
    Write-Host "  Failed: Cannot ping $remoteIP" -ForegroundColor Red
}

# Test WinRM
Write-Host "`nWinRM Test:" -ForegroundColor Yellow
try {
    $session = New-PSSession -ComputerName $remoteIP -Credential $credential -ErrorAction Stop
    Write-Host "  Success: WinRM connection established" -ForegroundColor Green
    
    # Test remote command
    $result = Invoke-Command -Session $session -ScriptBlock { 
        @{
            ComputerName = $env:COMPUTERNAME
            Domain = $env:USERDOMAIN
            PSVersion = $PSVersionTable.PSVersion.ToString()
        }
    }
    
    Write-Host "`nRemote System Info:" -ForegroundColor Cyan
    Write-Host "  Computer: $($result.ComputerName)"
    Write-Host "  Domain: $($result.Domain)"
    Write-Host "  PowerShell: $($result.PSVersion)"
    
    Remove-PSSession -Session $session
    Write-Host "`nConnection test successful!" -ForegroundColor Green
} catch {
    Write-Host "  Failed: $_" -ForegroundColor Red
}