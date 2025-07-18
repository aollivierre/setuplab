#Requires -RunAsAdministrator

# DNS Configuration
$PrimaryDNS = "192.168.100.198"
$SecondaryDNS = "1.1.1.1"

# Common Domain Controller ports to test
$DCPorts = @(
    @{Port = 53; Service = "DNS"},
    @{Port = 88; Service = "Kerberos"},
    @{Port = 135; Service = "RPC Endpoint Mapper"},
    @{Port = 139; Service = "NetBIOS"},
    @{Port = 389; Service = "LDAP"},
    @{Port = 445; Service = "SMB"},
    @{Port = 636; Service = "LDAPS"}
)

Write-Host "DNS Configuration Script" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Test if primary DNS (DC) is reachable
Write-Host "Testing connectivity to Domain Controller: $PrimaryDNS" -ForegroundColor Yellow
$pingResult = Test-Connection -ComputerName $PrimaryDNS -Count 2 -Quiet

if ($pingResult) {
    Write-Host "  [OK] Domain Controller is reachable" -ForegroundColor Green
    
    # Test common DC ports
    Write-Host "  Testing Domain Controller ports:" -ForegroundColor Yellow
    $portsOpen = 0
    foreach ($portInfo in $DCPorts) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($PrimaryDNS, $portInfo.Port)
            if ($tcpClient.Connected) {
                Write-Host ("    [OK] Port {0} ({1})" -f $portInfo.Port, $portInfo.Service) -ForegroundColor Green
                $portsOpen++
                $tcpClient.Close()
            }
        }
        catch {
            Write-Host ("    [X] Port {0} ({1})" -f $portInfo.Port, $portInfo.Service) -ForegroundColor Red
        }
    }
    
    if ($portsOpen -lt 3) {
        Write-Host ""
        Write-Host "WARNING: Less than 3 DC ports are open. This may not be a proper Domain Controller." -ForegroundColor Red
        $response = Read-Host "Do you want to continue? (Y/N)"
        if ($response -ne 'Y') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit
        }
    }
} else {
    Write-Host "  [X] Domain Controller is NOT reachable!" -ForegroundColor Red
    $response = Read-Host "Do you want to continue anyway? (Y/N)"
    if ($response -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

Write-Host ""
Write-Host "Configuring DNS on all active network adapters..." -ForegroundColor Cyan
Write-Host ""

# Get all active network adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

foreach ($adapter in $adapters) {
    Write-Host "Processing adapter: $($adapter.Name) [$($adapter.InterfaceDescription)]" -ForegroundColor Yellow
    
    try {
        # Get current DNS servers
        $currentDNS = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
        if ($currentDNS.ServerAddresses) {
            Write-Host "  Current DNS servers:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $currentDNS.ServerAddresses.Count; $i++) {
                $dnsType = if ($i -eq 0) { "Primary" } else { "Secondary" }
                Write-Host ("    {0}: {1}" -f $dnsType, $currentDNS.ServerAddresses[$i]) -ForegroundColor Cyan
            }
        } else {
            Write-Host "  Current DNS: Obtain automatically (DHCP)" -ForegroundColor Cyan
        }
        
        # Set new DNS servers
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $PrimaryDNS, $SecondaryDNS
        
        # Verify the change
        $newDNS = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
        Write-Host "  New DNS servers set:" -ForegroundColor Green
        Write-Host ("    Primary:   {0}" -f $newDNS.ServerAddresses[0]) -ForegroundColor Green
        Write-Host ("    Secondary: {0}" -f $newDNS.ServerAddresses[1]) -ForegroundColor Green
    }
    catch {
        Write-Host "  Error setting DNS for adapter: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Flush DNS cache
Write-Host "Flushing DNS cache..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache
    Write-Host "  [OK] DNS cache flushed" -ForegroundColor Green
} catch {
    Write-Host "  [X] Failed to flush DNS cache: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "DNS configuration complete." -ForegroundColor Cyan