# Configure WinRM TrustedHosts for cross-machine connectivity
param(
    [string]$RemoteHost = "198.18.1.157"
)

Write-Host "Configuring WinRM TrustedHosts..." -ForegroundColor Yellow

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges!" -ForegroundColor Red
    exit 1
}

# Get current TrustedHosts
$currentHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
Write-Host "Current TrustedHosts: $currentHosts"

# Add new host if not already present
if ($currentHosts -notlike "*$RemoteHost*") {
    if ([string]::IsNullOrEmpty($currentHosts)) {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RemoteHost -Force
    } else {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$currentHosts,$RemoteHost" -Force
    }
    Write-Host "Added $RemoteHost to TrustedHosts" -ForegroundColor Green
} else {
    Write-Host "$RemoteHost is already in TrustedHosts" -ForegroundColor Yellow
}

# Verify
$newHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
Write-Host "Updated TrustedHosts: $newHosts" -ForegroundColor Green