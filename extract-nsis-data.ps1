# Extract data from NSIS installer files

$ExtractPath = Join-Path $env:TEMP "filelocator_extracted"
$DataFiles = @(
    (Join-Path $ExtractPath '$TEMP\$_4_\$_5_'),
    (Join-Path $ExtractPath '$TEMP\$_4_\$_6_')
)

Write-Host "=== Extracting NSIS Data Files ===" -ForegroundColor Cyan

$sevenZip = "C:\Program Files\7-Zip\7z.exe"

foreach ($dataFile in $DataFiles) {
    if (Test-Path $dataFile) {
        $fileName = Split-Path $dataFile -Leaf
        Write-Host ""
        Write-Host "Processing: $fileName" -ForegroundColor Yellow
        
        $dataExtractPath = Join-Path $env:TEMP "nsis_data_$fileName"
        if (Test-Path $dataExtractPath) {
            Remove-Item $dataExtractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $dataExtractPath -Force | Out-Null
        
        # Try to extract with 7-Zip
        try {
            Write-Host "Extracting with 7-Zip..." -ForegroundColor Gray
            $process = Start-Process -FilePath $sevenZip -ArgumentList "x", "`"$dataFile`"", "-o`"$dataExtractPath`"", "-y" -Wait -PassThru -WindowStyle Hidden
            
            if ($process.ExitCode -eq 0) {
                Write-Host "Extraction successful" -ForegroundColor Green
                
                # Look for MSI files
                $msiFiles = Get-ChildItem -Path $dataExtractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
                if ($msiFiles) {
                    Write-Host "FOUND MSI FILES:" -ForegroundColor Green
                    $msiFiles | ForEach-Object {
                        Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Green
                        Write-Host "    Path: $($_.FullName)" -ForegroundColor Gray
                        
                        # Test this MSI for silent installation
                        Write-Host ""
                        Write-Host "Testing silent installation of: $($_.Name)" -ForegroundColor Yellow
                        Write-Host "Command: msiexec /i `"$($_.FullName)`" /quiet /norestart" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
                        
                        $installProcess = Start-Process -FilePath "msiexec" -ArgumentList "/i", "`"$($_.FullName)`"", "/quiet", "/norestart" -Wait -PassThru
                        Write-Host "Installation exit code: $($installProcess.ExitCode)" -ForegroundColor $(if ($installProcess.ExitCode -eq 0) { "Green" } else { "Yellow" })
                        
                        # Check if installed
                        Start-Sleep -Seconds 3
                        $installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
                        if (Test-Path $installedPath) {
                            Write-Host "SUCCESS: FileLocator Pro installed!" -ForegroundColor Green
                            Write-Host "DID YOU SEE ANY UI DIALOGS? (Please confirm)" -ForegroundColor Red
                            return
                        } else {
                            Write-Host "Installation failed or not complete" -ForegroundColor Yellow
                        }
                    }
                } else {
                    Write-Host "No MSI files found" -ForegroundColor Yellow
                    
                    # Show what was extracted
                    Write-Host "Extracted contents:" -ForegroundColor Gray
                    Get-ChildItem -Path $dataExtractPath -Recurse | Select-Object -First 10 | ForEach-Object {
                        Write-Host "  $($_.Name) - $($_.Extension)" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "7-Zip extraction failed with code: $($process.ExitCode)" -ForegroundColor Red
            }
        } catch {
            Write-Host "Extraction error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Data file not found: $dataFile" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== NSIS Data Extraction Complete ===" -ForegroundColor Cyan