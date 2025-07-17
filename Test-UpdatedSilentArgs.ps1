#Requires -Version 5.1
<#
.SYNOPSIS
    Test updated silent installation arguments for FileLocator Pro and Warp Terminal
#>

Write-Host "Testing Updated Silent Installation Arguments" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Load the updated config
$configPath = Join-Path $PSScriptRoot "software-config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Find the specific software entries
$fileLocator = $config.software | Where-Object { $_.name -eq "FileLocator Pro" }
$warpTerminal = $config.software | Where-Object { $_.name -eq "Warp Terminal" }

Write-Host "`nConfiguration Summary:" -ForegroundColor Yellow

Write-Host "`nFileLocator Pro:" -ForegroundColor Green
Write-Host "  Download URL: $($fileLocator.downloadUrl)" -ForegroundColor Gray
Write-Host "  Install Type: $($fileLocator.installType)" -ForegroundColor Gray
Write-Host "  Install Arguments: $($fileLocator.installArguments -join ' ')" -ForegroundColor Cyan

Write-Host "`nWarp Terminal:" -ForegroundColor Green
Write-Host "  Download URL: $($warpTerminal.downloadUrl)" -ForegroundColor Gray
Write-Host "  Install Type: $($warpTerminal.installType)" -ForegroundColor Gray
Write-Host "  Install Arguments: $($warpTerminal.installArguments -join ' ')" -ForegroundColor Cyan

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "Summary of Changes:" -ForegroundColor Yellow
Write-Host "1. FileLocator Pro: Changed from '/S' to '/VERYSILENT'" -ForegroundColor Green
Write-Host "2. Warp Terminal: Changed from '/S' to '/VERYSILENT /SUPPRESSMSGBOXES'" -ForegroundColor Green

Write-Host "`nThese changes should resolve the silent installation issues." -ForegroundColor Cyan
Write-Host "FileLocator Pro now uses the Inno Setup silent parameter." -ForegroundColor Gray
Write-Host "Warp Terminal now uses Inno Setup parameters with message suppression." -ForegroundColor Gray

# Offer to test downloads (without installing)
Write-Host "`nWould you like to validate the download URLs? (y/n): " -ForegroundColor Yellow -NoNewline
$response = Read-Host

if ($response -eq 'y') {
    Write-Host "`nValidating URLs..." -ForegroundColor Cyan
    
    foreach ($software in @($fileLocator, $warpTerminal)) {
        Write-Host "`nTesting: $($software.name)" -ForegroundColor Yellow
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $response = Invoke-WebRequest -Uri $software.downloadUrl -Method Head -UseBasicParsing -TimeoutSec 10
            Write-Host "  Status: $($response.StatusCode) - OK" -ForegroundColor Green
            
            if ($response.Headers['Content-Length']) {
                $sizeMB = [math]::Round([int64]$response.Headers['Content-Length'] / 1MB, 2)
                Write-Host "  File Size: $sizeMB MB" -ForegroundColor Green
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 'MethodNotAllowed') {
                Write-Host "  HEAD not allowed, but URL is valid" -ForegroundColor Yellow
            } else {
                Write-Host "  ERROR: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nConfiguration updates complete!" -ForegroundColor Green