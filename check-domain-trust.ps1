# Check current domain and trust relationships
Write-Host "Current Domain Information:" -ForegroundColor Yellow
Write-Host "  Computer Name: $env:COMPUTERNAME"
Write-Host "  Domain: $env:USERDOMAIN"
Write-Host "  DNS Domain: $env:USERDNSDOMAIN"

# Check if we can resolve the target machine
Write-Host "`nDNS Resolution Test:" -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName -Name "198.18.1.153" -ErrorAction Stop
    Write-Host "  IP resolves to: $($dnsResult.NameHost)" -ForegroundColor Green
} catch {
    Write-Host "  Failed to resolve: $_" -ForegroundColor Red
}

# Check for xyz.local domain
try {
    $xyzDC = Resolve-DnsName -Name "xyz.local" -ErrorAction Stop
    Write-Host "  xyz.local domain controller: $($xyzDC.IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "  Cannot resolve xyz.local domain" -ForegroundColor Red
}

Write-Host "`nDomain Trust:" -ForegroundColor Yellow
Write-Host "  Cross-domain PowerShell remoting requires either:"
Write-Host "  1. Both machines in the same domain"
Write-Host "  2. Domain trust relationship between abc.local and xyz.local"
Write-Host "  3. TrustedHosts configuration (less secure)"
Write-Host "  4. HTTPS/Certificate-based authentication"

Write-Host "`nRecommendation:" -ForegroundColor Cyan
Write-Host "  For testing, you can either:"
Write-Host "  1. Move this VM to xyz.local domain (as suggested)"
Write-Host "  2. Configure TrustedHosts (temporary, less secure)"
Write-Host "  3. Run the setup script locally on the target machine"