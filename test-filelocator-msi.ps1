# FileLocator Pro MSI-based Silent Installation Test

[CmdletBinding()]
param(
    [string]$Method = "extract"
)

$FileLocatorUrl = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
$TempPath = Join-Path $env:TEMP "filelocator_test.exe"
$ExtractPath = Join-Path $env:TEMP "filelocator_extract"

Write-Host "=== FileLocator Pro MSI-based Installation Test ===" -ForegroundColor Cyan
Write-Host "Method: $Method" -ForegroundColor Yellow
Write-Host ""

# Download the installer
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

switch ($Method) {
    "extract" {
        Write-Host "Attempting to extract MSI from EXE..." -ForegroundColor Yellow
        
        # Create extraction directory
        if (Test-Path $ExtractPath) {
            Remove-Item $ExtractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        
        # Try common extraction switches
        $extractSwitches = @(
            "/extract:$ExtractPath",
            "/x:$ExtractPath",
            "-x:$ExtractPath", 
            "/s /x:$ExtractPath",
            "/a /s /v`"TARGETDIR=$ExtractPath`""
        )
        
        foreach ($switch in $extractSwitches) {
            Write-Host "Trying: $TempPath $switch" -ForegroundColor Gray
            try {
                $process = Start-Process -FilePath $TempPath -ArgumentList $switch -Wait -PassThru -WindowStyle Hidden
                Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Gray
                
                # Check if MSI was extracted
                $msiFiles = Get-ChildItem -Path $ExtractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
                if ($msiFiles) {
                    Write-Host "SUCCESS: Found MSI files:" -ForegroundColor Green
                    $msiFiles | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Green }
                    return $msiFiles[0].FullName
                }
            } catch {
                Write-Host "Failed: $_" -ForegroundColor Red
            }
        }
        
        Write-Host "Could not extract MSI. Trying alternative approaches..." -ForegroundColor Yellow
    }
    
    "installshield" {
        Write-Host "Testing InstallShield-style switches..." -ForegroundColor Yellow
        $switches = @(
            "/s /v`"/qn`"",
            "/s /v`"/quiet`"",
            "/s /v`"/qn /norestart`""
        )
        
        foreach ($switch in $switches) {
            Write-Host "Command: $TempPath $switch" -ForegroundColor Gray
            Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
            $process = Start-Process -FilePath $TempPath -ArgumentList $switch -Wait -PassThru
            Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })
            
            # Check installation
            $installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            if (Test-Path $installedPath) {
                Write-Host "SUCCESS: FileLocator Pro installed!" -ForegroundColor Green
                return
            }
            Write-Host "Not installed with this switch" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    
    "msiexec" {
        # First try to extract MSI
        Write-Host "Looking for extracted MSI..." -ForegroundColor Yellow
        $msiFiles = Get-ChildItem -Path $ExtractPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
        
        if (-not $msiFiles) {
            Write-Host "No MSI found. Run extract method first." -ForegroundColor Red
            return
        }
        
        $msiPath = $msiFiles[0].FullName
        Write-Host "Using MSI: $msiPath" -ForegroundColor Green
        
        # Test different msiexec approaches
        $msiSwitches = @(
            "/i `"$msiPath`" /quiet /norestart",
            "/i `"$msiPath`" /qn /norestart",
            "/i `"$msiPath`" /passive /norestart"
        )
        
        foreach ($switch in $msiSwitches) {
            Write-Host "Command: msiexec $switch" -ForegroundColor Gray
            Write-Host "WATCH FOR ANY UI DIALOGS - Starting installation..." -ForegroundColor Red
            $process = Start-Process -FilePath "msiexec" -ArgumentList $switch -Wait -PassThru
            Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })
            
            # Check installation
            $installedPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            if (Test-Path $installedPath) {
                Write-Host "SUCCESS: FileLocator Pro installed!" -ForegroundColor Green
                return
            }
            Write-Host "Not installed with this switch" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan