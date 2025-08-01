# Extract FileLocator Pro MSI using 7-Zip

$FileLocatorUrl = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
$TempPath = Join-Path $env:TEMP "filelocator_test.exe"
$ExtractPath = Join-Path $env:TEMP "filelocator_extracted"

Write-Host "=== Extract FileLocator Pro MSI using 7-Zip ===" -ForegroundColor Cyan

# Check if 7-Zip is available
$sevenZip = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $sevenZip) {
    Write-Host "7-Zip not found. Installing from our previous installation..." -ForegroundColor Yellow
    
    # Check if it was installed by our setup
    if (Test-Path "C:\Program Files\7-Zip\7z.exe") {
        $sevenZip = "C:\Program Files\7-Zip\7z.exe"
        Write-Host "Found 7-Zip: $sevenZip" -ForegroundColor Green
    } else {
        Write-Host "7-Zip not available. Cannot extract." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Found 7-Zip: $sevenZip" -ForegroundColor Green
}

# Download installer if needed
if (-not (Test-Path $TempPath)) {
    Write-Host "Downloading FileLocator Pro installer..." -ForegroundColor Yellow
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

# Create extraction directory
if (Test-Path $ExtractPath) {
    Remove-Item $ExtractPath -Recurse -Force
}
New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null

# Extract using 7-Zip
Write-Host "Extracting using 7-Zip..." -ForegroundColor Yellow
Write-Host "Command: `"$sevenZip`" x `"$TempPath`" -o`"$ExtractPath`" -y" -ForegroundColor Gray

try {
    $process = Start-Process -FilePath $sevenZip -ArgumentList "x", "`"$TempPath`"", "-o`"$ExtractPath`"", "-y" -Wait -PassThru -WindowStyle Hidden
    Write-Host "7-Zip exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })
    
    # Look for MSI files
    Write-Host "Looking for MSI files..." -ForegroundColor Yellow
    $msiFiles = Get-ChildItem -Path $ExtractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
    
    if ($msiFiles) {
        Write-Host "SUCCESS: Found MSI files:" -ForegroundColor Green
        $msiFiles | ForEach-Object { 
            Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Green 
            Write-Host "    Full path: $($_.FullName)" -ForegroundColor Gray
        }
        
        # Test silent installation with the largest MSI (likely the main installer)
        $mainMsi = $msiFiles | Sort-Object Length -Descending | Select-Object -First 1
        Write-Host ""
        Write-Host "Testing silent installation with: $($mainMsi.Name)" -ForegroundColor Yellow
        Write-Host "Command: msiexec /i `"$($mainMsi.FullName)`" /quiet /norestart" -ForegroundColor Gray
        Write-Host ""
        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
        
        $installProcess = Start-Process -FilePath "msiexec" -ArgumentList "/i", "`"$($mainMsi.FullName)`"", "/quiet", "/norestart" -Wait -PassThru
        Write-Host "Installation exit code: $($installProcess.ExitCode)" -ForegroundColor $(if ($installProcess.ExitCode -eq 0) { "Green" } else { "Yellow" })
        
        # Check if installed
        Start-Sleep -Seconds 3
        $installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
        if (Test-Path $installedPath) {
            Write-Host "SUCCESS: FileLocator Pro installed at: $installedPath" -ForegroundColor Green
            
            # Get version
            try {
                $version = (Get-Item $installedPath).VersionInfo.ProductVersion
                Write-Host "Version: $version" -ForegroundColor Gray
            } catch {}
            
            Write-Host ""
            Write-Host "DID YOU SEE ANY UI DIALOGS DURING INSTALLATION? (Please confirm)" -ForegroundColor Red
        } else {
            Write-Host "Installation failed - FileLocator Pro not found" -ForegroundColor Red
        }
        
    } else {
        Write-Host "No MSI files found in extraction" -ForegroundColor Red
        Write-Host "Extracted files:" -ForegroundColor Yellow
        Get-ChildItem -Path $ExtractPath -Recurse | ForEach-Object {
            Write-Host "  $($_.Name) - $($_.Extension)" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "Extraction failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Extraction Complete ===" -ForegroundColor Cyan