# Test FileLocator Pro MSI Direct Download and Silent Installation

$MsiZipUrl = "https://download.mythicsoft.com/flp/3522/filelocator_x64_msi_3522.zip"
$TempZipPath = Join-Path $env:TEMP "filelocator_msi.zip"
$ExtractPath = Join-Path $env:TEMP "filelocator_msi_extracted"

Write-Host "=== FileLocator Pro MSI Direct Download Test ===" -ForegroundColor Cyan
Write-Host "Downloading MSI package: $MsiZipUrl" -ForegroundColor Yellow

# Download the MSI ZIP file
try {
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $MsiZipUrl -Destination $TempZipPath -ErrorAction Stop
    } else {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($MsiZipUrl, $TempZipPath)
        $webClient.Dispose()
    }
    Write-Host "Download completed: $TempZipPath" -ForegroundColor Green
    $zipSize = (Get-Item $TempZipPath).Length / 1MB
    Write-Host "ZIP file size: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Gray
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract the ZIP file
Write-Host ""
Write-Host "Extracting ZIP file..." -ForegroundColor Yellow

if (Test-Path $ExtractPath) {
    Remove-Item $ExtractPath -Recurse -Force
}
New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null

try {
    # Use .NET to extract ZIP
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZipPath, $ExtractPath)
    Write-Host "Extraction completed" -ForegroundColor Green
    
    # List extracted files
    Write-Host ""
    Write-Host "Extracted files:" -ForegroundColor Yellow
    $extractedFiles = Get-ChildItem -Path $ExtractPath -Recurse
    $extractedFiles | ForEach-Object {
        $size = if ($_.PSIsContainer) { "[DIR]" } else { "$([math]::Round($_.Length / 1MB, 2)) MB" }
        Write-Host "  $($_.Name) - $size" -ForegroundColor Gray
    }
    
    # Find the MSI file
    $msiFiles = $extractedFiles | Where-Object { $_.Extension -eq '.msi' }
    
    if ($msiFiles) {
        $msiFile = $msiFiles[0]
        Write-Host ""
        Write-Host "Found MSI file: $($msiFile.Name)" -ForegroundColor Green
        Write-Host "MSI size: $([math]::Round($msiFile.Length / 1MB, 2)) MB" -ForegroundColor Gray
        Write-Host "Full path: $($msiFile.FullName)" -ForegroundColor Gray
        
        # Test silent installation
        Write-Host ""
        Write-Host "Testing silent installation..." -ForegroundColor Yellow
        Write-Host "Command: msiexec /i `"$($msiFile.FullName)`" /quiet /norestart" -ForegroundColor Gray
        Write-Host ""
        Write-Host "*** WATCH FOR ANY UI DIALOGS - Starting installation... ***" -ForegroundColor Red
        Write-Host ""
        
        $installProcess = Start-Process -FilePath "msiexec" -ArgumentList "/i", "`"$($msiFile.FullName)`"", "/quiet", "/norestart" -Wait -PassThru
        
        Write-Host "Installation completed with exit code: $($installProcess.ExitCode)" -ForegroundColor $(if ($installProcess.ExitCode -eq 0) { "Green" } else { "Yellow" })
        
        # Check if FileLocator Pro was installed
        Write-Host ""
        Write-Host "Checking installation..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        $installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
        if (Test-Path $installedPath) {
            Write-Host "SUCCESS: FileLocator Pro installed at: $installedPath" -ForegroundColor Green
            
            # Get version info
            try {
                $versionInfo = (Get-Item $installedPath).VersionInfo
                Write-Host "Version: $($versionInfo.ProductVersion)" -ForegroundColor Gray
                Write-Host "Company: $($versionInfo.CompanyName)" -ForegroundColor Gray
            } catch {
                Write-Host "Could not retrieve version info" -ForegroundColor Yellow
            }
            
            # Check registry entry
            try {
                $regEntry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
                           Where-Object { $_.DisplayName -like "*FileLocator*" } | 
                           Select-Object -First 1
                if ($regEntry) {
                    Write-Host "Registry entry: $($regEntry.DisplayName) v$($regEntry.DisplayVersion)" -ForegroundColor Gray
                }
            } catch {}
            
            Write-Host ""
            Write-Host "*** CRITICAL QUESTION: DID YOU SEE ANY UI DIALOGS DURING INSTALLATION? ***" -ForegroundColor Red
            Write-Host "*** Please confirm if the installation was completely silent ***" -ForegroundColor Red
            
        } else {
            Write-Host "FAILED: FileLocator Pro not found at expected location" -ForegroundColor Red
            
            # Check for alternative installation paths
            $altPaths = @(
                "C:\Program Files (x86)\Mythicsoft\FileLocator Pro\FileLocatorPro.exe",
                "$env:ProgramFiles\Mythicsoft\FileLocator Pro\FileLocatorPro.exe",
                "${env:ProgramFiles(x86)}\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            )
            
            foreach ($altPath in $altPaths) {
                if (Test-Path $altPath) {
                    Write-Host "Found at alternative path: $altPath" -ForegroundColor Yellow
                    break
                }
            }
            
            # Check registry for any FileLocator installations
            Write-Host "Checking registry..." -ForegroundColor Yellow
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            foreach ($regPath in $regPaths) {
                Get-ItemProperty $regPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*FileLocator*" } | 
                ForEach-Object {
                    Write-Host "Found in registry: $($_.DisplayName) - $($_.DisplayVersion)" -ForegroundColor Yellow
                }
            }
        }
        
    } else {
        Write-Host "ERROR: No MSI file found in extracted contents" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up temporary files..." -ForegroundColor Gray
Remove-Item $TempZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan