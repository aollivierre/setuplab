# Script to enable cross-domain PowerShell remoting
param(
    [Parameter(Mandatory = $false)]
    [string]$RemoteComputer = "198.18.1.153",
    
    [Parameter(Mandatory = $false)]
    [switch]$ConfigureTrustedHosts
)

Write-Host "Cross-Domain Remoting Configuration" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

# Check current TrustedHosts
Write-Host "`nCurrent TrustedHosts configuration:" -ForegroundColor Yellow
$currentTrustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
if ($currentTrustedHosts) {
    Write-Host "  $($currentTrustedHosts.Value)" -ForegroundColor White
} else {
    Write-Host "  <empty>" -ForegroundColor Gray
}

if ($ConfigureTrustedHosts) {
    Write-Host "`nConfiguring TrustedHosts for cross-domain remoting..." -ForegroundColor Yellow
    
    try {
        # Backup current value
        $backupValue = if ($currentTrustedHosts) { $currentTrustedHosts.Value } else { "" }
        
        # Add the remote computer to TrustedHosts
        if ($backupValue) {
            $newValue = "$backupValue,$RemoteComputer"
        } else {
            $newValue = $RemoteComputer
        }
        
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force
        Write-Host "Successfully added $RemoteComputer to TrustedHosts" -ForegroundColor Green
        
        # Enable CredSSP if needed (optional, more secure than basic auth)
        Enable-WSManCredSSP -Role Client -DelegateComputer $RemoteComputer -Force
        Write-Host "Enabled CredSSP for $RemoteComputer" -ForegroundColor Green
        
    } catch {
        Write-Host "Failed to configure TrustedHosts: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`nOptions for cross-domain remoting:" -ForegroundColor Yellow
    Write-Host "1. Configure TrustedHosts (less secure, but quick for testing)" -ForegroundColor White
    Write-Host "   Run: .\enable-cross-domain-remoting.ps1 -ConfigureTrustedHosts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Use alternative remote execution method" -ForegroundColor White
    Write-Host "   - Copy script to target and run locally" -ForegroundColor Gray
    Write-Host "   - Use PsExec for remote execution" -ForegroundColor Gray
    Write-Host "   - Join this VM to xyz.local domain" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Create a launcher script on the target" -ForegroundColor White
    Write-Host "   - Use web-based launcher to download and run" -ForegroundColor Gray
}

Write-Host "`nTesting connectivity to $RemoteComputer..." -ForegroundColor Yellow
if (Test-Connection -ComputerName $RemoteComputer -Count 1 -Quiet) {
    Write-Host "  Network connectivity: OK" -ForegroundColor Green
} else {
    Write-Host "  Network connectivity: FAILED" -ForegroundColor Red
}