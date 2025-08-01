# Analyze FileLocator Pro installer to determine its type

$FileLocatorUrl = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
$TempPath = Join-Path $env:TEMP "filelocator_analyze.exe"

Write-Host "=== FileLocator Pro Installer Analysis ===" -ForegroundColor Cyan

# Download if not exists
if (-not (Test-Path $TempPath)) {
    Write-Host "Downloading installer for analysis..." -ForegroundColor Yellow
    try {
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $FileLocatorUrl -Destination $TempPath -ErrorAction Stop
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($FileLocatorUrl, $TempPath)
            $webClient.Dispose()
        }
        Write-Host "Download completed" -ForegroundColor Green
    } catch {
        Write-Host "Download failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Get file info
$fileInfo = Get-Item $TempPath
Write-Host ""
Write-Host "File Information:" -ForegroundColor Yellow
Write-Host "  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor Gray
Write-Host "  Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray

# Check file signature/version info
try {
    $versionInfo = $fileInfo.VersionInfo
    Write-Host ""
    Write-Host "Version Information:" -ForegroundColor Yellow
    Write-Host "  Company: $($versionInfo.CompanyName)" -ForegroundColor Gray
    Write-Host "  Product: $($versionInfo.ProductName)" -ForegroundColor Gray
    Write-Host "  Version: $($versionInfo.ProductVersion)" -ForegroundColor Gray 
    Write-Host "  Description: $($versionInfo.FileDescription)" -ForegroundColor Gray
} catch {
    Write-Host "Could not get version info" -ForegroundColor Yellow
}

# Check for common installer signatures
Write-Host ""
Write-Host "Checking installer type..." -ForegroundColor Yellow

# Read first few bytes to check for installer signatures
$bytes = [System.IO.File]::ReadAllBytes($TempPath)
$header = [System.Text.Encoding]::ASCII.GetString($bytes[0..1023])

if ($header -match "Inno Setup") {
    Write-Host "  Type: Inno Setup installer" -ForegroundColor Green
    Write-Host "  Silent switches: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -ForegroundColor Cyan
} elseif ($header -match "NSIS") {
    Write-Host "  Type: NSIS installer" -ForegroundColor Green
    Write-Host "  Silent switches: /S" -ForegroundColor Cyan
} elseif ($header -match "InstallShield") {
    Write-Host "  Type: InstallShield installer" -ForegroundColor Green
    Write-Host "  Silent switches: /S /v\"/qn\"" -ForegroundColor Cyan
} elseif ($header -match "WiX") {
    Write-Host "  Type: WiX installer" -ForegroundColor Green
    Write-Host "  Silent switches: /quiet /norestart" -ForegroundColor Cyan
} else {
    Write-Host "  Type: Unknown or custom installer" -ForegroundColor Yellow
}

# Try to extract help information
Write-Host ""
Write-Host "Attempting to get help information..." -ForegroundColor Yellow

try {
    Write-Host "Testing /? switch..." -ForegroundColor Gray
    $helpProcess = Start-Process -FilePath $TempPath -ArgumentList "/?" -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\flp_help.txt" -RedirectStandardError "$env:TEMP\flp_error.txt" 2>$null
    
    if (Test-Path "$env:TEMP\flp_help.txt") {
        $helpContent = Get-Content "$env:TEMP\flp_help.txt" -Raw
        if ($helpContent.Trim()) {
            Write-Host "Help output:" -ForegroundColor Green
            Write-Host $helpContent -ForegroundColor Gray
        }
        Remove-Item "$env:TEMP\flp_help.txt" -Force -ErrorAction SilentlyContinue
    }
    
    Remove-Item "$env:TEMP\flp_error.txt" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "Could not get help info: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan

# Cleanup
Remove-Item $TempPath -Force -ErrorAction SilentlyContinue