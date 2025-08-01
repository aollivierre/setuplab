# Analyze extracted FileLocator Pro files

$ExtractPath = Join-Path $env:TEMP "filelocator_extracted"

Write-Host "=== Analyzing Extracted FileLocator Pro Files ===" -ForegroundColor Cyan

if (Test-Path $ExtractPath) {
    Write-Host "Extracted files structure:" -ForegroundColor Yellow
    Get-ChildItem -Path $ExtractPath -Recurse | ForEach-Object {
        $indent = "  " * (($_.FullName.Replace($ExtractPath, "").Split('\').Length - 2))
        $size = if ($_.PSIsContainer) { "[DIR]" } else { "$([math]::Round($_.Length / 1KB, 1)) KB" }
        Write-Host "$indent$($_.Name) - $size" -ForegroundColor Gray
    }
    
    # Look for any installer files or data
    Write-Host ""
    Write-Host "Looking for installer data files..." -ForegroundColor Yellow
    
    $dataFiles = Get-ChildItem -Path $ExtractPath -Recurse | Where-Object { 
        $_.Extension -in '.dat', '.cab', '.7z', '.zip', '.exe', '.msi' -or 
        $_.Name -like '*install*' -or 
        $_.Name -like '*setup*' -or
        $_.Length -gt 10MB
    }
    
    if ($dataFiles) {
        Write-Host "Found potential installer data files:" -ForegroundColor Green
        $dataFiles | ForEach-Object {
            Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Green
            Write-Host "    Path: $($_.FullName)" -ForegroundColor Gray
        }
        
        # Check if any of these might contain MSI
        foreach ($file in $dataFiles) {
            if ($file.Extension -in '.cab', '.7z', '.zip') {
                Write-Host ""
                Write-Host "Trying to extract: $($file.Name)" -ForegroundColor Yellow
                $subExtractPath = Join-Path $env:TEMP "sub_extract_$($file.BaseName)"
                
                if (Test-Path $subExtractPath) {
                    Remove-Item $subExtractPath -Recurse -Force
                }
                New-Item -ItemType Directory -Path $subExtractPath -Force | Out-Null
                
                try {
                    $sevenZip = "C:\Program Files\7-Zip\7z.exe"
                    $process = Start-Process -FilePath $sevenZip -ArgumentList "x", "`"$($file.FullName)`"", "-o`"$subExtractPath`"", "-y" -Wait -PassThru -WindowStyle Hidden
                    
                    if ($process.ExitCode -eq 0) {
                        $msiInSub = Get-ChildItem -Path $subExtractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
                        if ($msiInSub) {
                            Write-Host "FOUND MSI in $($file.Name):" -ForegroundColor Green
                            $msiInSub | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Green }
                        } else {
                            Write-Host "No MSI found in $($file.Name)" -ForegroundColor Gray
                        }
                    }
                } catch {
                    Write-Host "Could not extract $($file.Name): $_" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "No obvious installer data files found" -ForegroundColor Yellow
    }
    
    # Check for NSIS specific files
    Write-Host ""
    Write-Host "Checking for NSIS installer structure..." -ForegroundColor Yellow
    $nsisFiles = Get-ChildItem -Path $ExtractPath -Recurse | Where-Object { 
        $_.Name -like '*NSIS*' -or $_.Name -eq 'System.dll' -or $_.Directory.Name -eq '$PLUGINSDIR'
    }
    
    if ($nsisFiles) {
        Write-Host "This appears to be an NSIS installer" -ForegroundColor Green
        Write-Host "NSIS installers typically use /S for silent installation" -ForegroundColor Cyan
        Write-Host "But this one might have custom behavior..." -ForegroundColor Yellow
    }
    
} else {
    Write-Host "Extraction path not found: $ExtractPath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan