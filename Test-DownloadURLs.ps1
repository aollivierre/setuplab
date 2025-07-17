#Requires -Version 5.1
<#
.SYNOPSIS
    Test script to validate download URLs for all software in software-config.json
.DESCRIPTION
    This script downloads all software packages to validate URLs without installing them.
    It reports which URLs are working and which need to be fixed.
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "software-config.json",
    [string]$TempPath = (Join-Path $env:TEMP "SetupLab_URLTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
)

# Create temp directory
New-Item -ItemType Directory -Path $TempPath -Force | Out-Null

Write-Host "Download URL Validation Test" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Temp directory: $TempPath" -ForegroundColor Gray
Write-Host ""

# Load configuration
$configPath = if ([System.IO.Path]::IsPathRooted($ConfigFile)) {
    $ConfigFile
} else {
    Join-Path $PSScriptRoot $ConfigFile
}

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$results = @()

# Test each software download
foreach ($software in $config.software) {
    if (-not $software.enabled) {
        continue
    }
    
    Write-Host "`nTesting: $($software.name)" -ForegroundColor Yellow
    Write-Host "URL: $($software.downloadUrl)" -ForegroundColor Gray
    
    $result = [PSCustomObject]@{
        Name = $software.name
        Category = $software.category
        URL = $software.downloadUrl
        Status = "Unknown"
        FileSize = 0
        Error = ""
        Filename = ""
    }
    
    try {
        # Determine filename
        if ($software.downloadUrl -match 'download\?') {
            # Dynamic URL - use software name
            $filename = "$($software.name -replace '[^a-zA-Z0-9]', '')_installer"
            $extension = switch ($software.installType) {
                'MSI' { '.msi' }
                'MSIX' { '.msixbundle' }
                'EXE' { '.exe' }
                default { '.exe' }
            }
            $filename += $extension
        } else {
            $uri = [System.Uri]$software.downloadUrl
            $filename = [System.IO.Path]::GetFileName($uri.LocalPath)
            if ([string]::IsNullOrEmpty($filename)) {
                $filename = "$($software.name -replace '[^a-zA-Z0-9]', '')_installer.exe"
            }
        }
        
        $result.Filename = $filename
        $outputPath = Join-Path $TempPath $filename
        
        # Enable TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Test with HEAD request first
        Write-Host "  Checking URL availability..." -ForegroundColor Gray
        try {
            $headResponse = Invoke-WebRequest -Uri $software.downloadUrl -Method Head -UseBasicParsing -TimeoutSec 10
            Write-Host "  HTTP Status: $($headResponse.StatusCode)" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 'MethodNotAllowed') {
                Write-Host "  HEAD method not allowed, trying GET..." -ForegroundColor Yellow
            } else {
                throw
            }
        }
        
        # Download file
        Write-Host "  Downloading to: $outputPath" -ForegroundColor Gray
        $startTime = Get-Date
        
        # Try BITS first
        try {
            Start-BitsTransfer -Source $software.downloadUrl -Destination $outputPath -ErrorAction Stop
            Write-Host "  Download completed using BITS" -ForegroundColor Green
        }
        catch {
            # Fallback to Invoke-WebRequest
            Write-Host "  BITS failed, using Invoke-WebRequest..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $software.downloadUrl -OutFile $outputPath -UseBasicParsing
            Write-Host "  Download completed using Invoke-WebRequest" -ForegroundColor Green
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # Verify file
        if (Test-Path $outputPath) {
            $fileInfo = Get-Item $outputPath
            $result.FileSize = [math]::Round($fileInfo.Length / 1MB, 2)
            $result.Status = "Success"
            
            Write-Host "  File size: $($result.FileSize) MB" -ForegroundColor Green
            Write-Host "  Download time: $($duration.TotalSeconds.ToString('0.0')) seconds" -ForegroundColor Green
            Write-Host "  Status: SUCCESS" -ForegroundColor Green
            
            # Verify file type
            $bytes = [System.IO.File]::ReadAllBytes($outputPath) | Select-Object -First 4
            $signature = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
            
            $expectedType = switch ($software.installType) {
                'MSI' { @('D0CF11E0', '504B0304') }  # MSI or Office Open XML
                'EXE' { @('4D5A') }  # MZ header
                'MSIX' { @('504B0304') }  # ZIP/MSIX
                default { @('4D5A', 'D0CF11E0', '504B0304') }
            }
            
            $validSignature = $false
            foreach ($sig in $expectedType) {
                if ($signature.StartsWith($sig)) {
                    $validSignature = $true
                    break
                }
            }
            
            if ($validSignature) {
                Write-Host "  File signature valid for $($software.installType)" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: File signature doesn't match expected type ($($software.installType))" -ForegroundColor Yellow
                Write-Host "  Signature: $signature" -ForegroundColor Yellow
            }
        }
        else {
            $result.Status = "Failed"
            $result.Error = "File not found after download"
            Write-Host "  Status: FAILED - File not found" -ForegroundColor Red
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Error = $_.Exception.Message
        Write-Host "  Status: FAILED" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  HTTP Status Code: $statusCode" -ForegroundColor Red
        }
    }
    
    $results += $result
}

# Summary report
Write-Host "`n`nSUMMARY REPORT" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_.Status -eq "Success" }).Count
$failedCount = ($results | Where-Object { $_.Status -eq "Failed" }).Count

Write-Host "Total tested: $($results.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failedCount" -ForegroundColor Red

# Successful downloads
Write-Host "`nSuccessful Downloads:" -ForegroundColor Green
$results | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
    Write-Host ("  {0,-30} {1,10} MB  {2}" -f $_.Name, $_.FileSize, $_.Filename) -ForegroundColor Gray
}

# Failed downloads
if ($failedCount -gt 0) {
    Write-Host "`nFailed Downloads:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Red
        Write-Host "    URL: $($_.URL)" -ForegroundColor Gray
        Write-Host "    Error: $($_.Error)" -ForegroundColor Gray
    }
}

# Export results
$reportPath = Join-Path $PSScriptRoot "download-test-results.json"
$results | ConvertTo-Json -Depth 10 | Set-Content $reportPath
Write-Host "`nDetailed results exported to: $reportPath" -ForegroundColor Cyan

# Cleanup
Write-Host "`nCleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nTest completed!" -ForegroundColor Green