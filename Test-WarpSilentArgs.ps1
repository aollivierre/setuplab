#Requires -Version 5.1
Write-Host "Testing Warp Terminal Silent Installation Arguments" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Common silent installation arguments to test
$silentArgs = @(
    @{ Args = @("/S"); Description = "NSIS silent" },
    @{ Args = @("/VERYSILENT"); Description = "Inno Setup very silent" },
    @{ Args = @("/SILENT"); Description = "Inno Setup silent" },
    @{ Args = @("/quiet"); Description = "Standard quiet" },
    @{ Args = @("/q"); Description = "Short quiet" },
    @{ Args = @("--silent"); Description = "Long form silent" },
    @{ Args = @("-s"); Description = "Short form silent" },
    @{ Args = @("/S", "/D=%LOCALAPPDATA%\Programs\Warp"); Description = "NSIS with install dir" },
    @{ Args = @("/?"); Description = "Help/Usage" },
    @{ Args = @("/h"); Description = "Help" },
    @{ Args = @("--help"); Description = "Long form help" }
)

Write-Host "`nDownloading Warp Terminal installer..." -ForegroundColor Yellow
$url = "https://releases.warp.dev/stable/v0.2025.07.09.08.11.stable_01/WarpSetup.exe"
$tempPath = [System.IO.Path]::Combine($env:TEMP, "WarpSetup_test.exe")

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
    Write-Host "Download complete: $tempPath" -ForegroundColor Green
    
    # Check file signature
    $sig = Get-AuthenticodeSignature -FilePath $tempPath
    Write-Host "`nDigital Signature: $($sig.SignerCertificate.Subject)" -ForegroundColor Gray
    
    # Try each argument set
    foreach ($test in $silentArgs) {
        Write-Host "`nTesting: $($test.Description)" -ForegroundColor Yellow
        Write-Host "Arguments: $($test.Args -join ' ')" -ForegroundColor Gray
        
        try {
            # Start process with timeout
            $proc = Start-Process -FilePath $tempPath -ArgumentList $test.Args -PassThru -WindowStyle Hidden
            
            # Wait for up to 5 seconds
            $timeout = 5000
            if (-not $proc.WaitForExit($timeout)) {
                Write-Host "  Process still running after $($timeout/1000) seconds" -ForegroundColor Yellow
                
                # Check if it created any processes
                $childProcs = Get-Process | Where-Object { $_.Parent.Id -eq $proc.Id } 2>$null
                if ($childProcs) {
                    Write-Host "  Child processes found: $($childProcs.Name -join ', ')" -ForegroundColor Yellow
                }
                
                # Kill the process
                $proc.Kill()
                Write-Host "  Process killed" -ForegroundColor Red
            } else {
                Write-Host "  Exit Code: $($proc.ExitCode)" -ForegroundColor Green
                
                # Common exit codes
                switch ($proc.ExitCode) {
                    0 { Write-Host "  SUCCESS: Installation completed" -ForegroundColor Green }
                    1 { Write-Host "  ERROR: General error" -ForegroundColor Red }
                    2 { Write-Host "  ERROR: User cancelled" -ForegroundColor Red }
                    3010 { Write-Host "  SUCCESS: Reboot required" -ForegroundColor Yellow }
                    1602 { Write-Host "  ERROR: User cancelled installation" -ForegroundColor Red }
                    1618 { Write-Host "  ERROR: Another installation in progress" -ForegroundColor Red }
                    1641 { Write-Host "  SUCCESS: Installation succeeded, reboot initiated" -ForegroundColor Yellow }
                    default { Write-Host "  Unknown exit code" -ForegroundColor Gray }
                }
            }
        }
        catch {
            Write-Host "  ERROR: $_" -ForegroundColor Red
        }
        
        # Small delay between tests
        Start-Sleep -Seconds 1
    }
    
    # Check if Warp was actually installed
    Write-Host "`nChecking for Warp installation..." -ForegroundColor Cyan
    $warpPath = "$env:LOCALAPPDATA\Programs\Warp\Warp.exe"
    if (Test-Path $warpPath) {
        Write-Host "Warp found at: $warpPath" -ForegroundColor Green
        
        # Get version info
        $versionInfo = (Get-Item $warpPath).VersionInfo
        Write-Host "Version: $($versionInfo.ProductVersion)" -ForegroundColor Green
    } else {
        Write-Host "Warp not found at expected location" -ForegroundColor Yellow
    }
    
    # Check registry
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        $warpReg = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                   Where-Object { $_.DisplayName -like "*Warp*" }
        if ($warpReg) {
            Write-Host "Registry entry found: $($warpReg.DisplayName)" -ForegroundColor Green
            break
        }
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
finally {
    # Cleanup
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Force
        Write-Host "`nTest file cleaned up" -ForegroundColor Gray
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green