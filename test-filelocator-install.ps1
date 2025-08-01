# FileLocator Pro Silent Installation Test Script
# Test different silent installation approaches systematically

[CmdletBinding()]
param(
    [string]$Method = "VERYSILENT"
)

$FileLocatorUrl = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
$TempPath = Join-Path $env:TEMP "filelocator_test.exe"

Write-Host "=== FileLocator Pro Silent Installation Test ===" -ForegroundColor Cyan
Write-Host "Method: $Method" -ForegroundColor Yellow
Write-Host "URL: $FileLocatorUrl" -ForegroundColor Gray
Write-Host ""

# Download the installer
Write-Host "Downloading FileLocator Pro installer..." -ForegroundColor Yellow
try {
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $FileLocatorUrl -Destination $TempPath -ErrorAction Stop
    } else {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($FileLocatorUrl, $TempPath)
        $webClient.Dispose()
    }
    Write-Host "Download completed: $TempPath" -ForegroundColor Green
    $fileSize = (Get-Item $TempPath).Length / 1MB
    Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Test the specified method
Write-Host ""
Write-Host "Testing installation method: $Method" -ForegroundColor Yellow

switch ($Method) {
    "VERYSILENT" {
        Write-Host "Command: $TempPath /VERYSILENT" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/VERYSILENT" -Wait -PassThru
    }
    "S" {
        Write-Host "Command: $TempPath /S" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/S" -Wait -PassThru
    }
    "SILENT" {
        Write-Host "Command: $TempPath /SILENT" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/SILENT" -Wait -PassThru
    }
    "Q" {
        Write-Host "Command: $TempPath /Q" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/Q" -Wait -PassThru
    }
    "QUIET" {
        Write-Host "Command: $TempPath /QUIET" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/QUIET" -Wait -PassThru
    }
    "SP" {
        Write-Host "Command: $TempPath /SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        $process = Start-Process -FilePath $TempPath -ArgumentList "/SP-", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait -PassThru
    }
    default {
        Write-Host "Unknown method: $Method" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Installation process completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })

# Check if FileLocator Pro was installed
Write-Host ""
Write-Host "Checking installation..." -ForegroundColor Yellow

$installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
if (Test-Path $installedPath) {
    Write-Host "SUCCESS: FileLocator Pro found at: $installedPath" -ForegroundColor Green
    
    # Get version info
    try {
        $versionInfo = (Get-Item $installedPath).VersionInfo
        Write-Host "Version: $($versionInfo.ProductVersion)" -ForegroundColor Gray
    } catch {
        Write-Host "Could not retrieve version info" -ForegroundColor Yellow
    }
} else {
    Write-Host "FAILED: FileLocator Pro not found at expected location" -ForegroundColor Red
    
    # Check registry
    Write-Host "Checking registry for FileLocator Pro..." -ForegroundColor Yellow
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $found = $false
    foreach ($regPath in $regPaths) {
        Get-ItemProperty $regPath -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like "*FileLocator*" } | 
        ForEach-Object {
            Write-Host "Found in registry: $($_.DisplayName) - $($_.DisplayVersion)" -ForegroundColor Green
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "Not found in registry either" -ForegroundColor Red
    }
}

# Cleanup
Remove-Item $TempPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host "DID YOU SEE ANY UI DIALOGS DURING INSTALLATION? (Please confirm)" -ForegroundColor Red