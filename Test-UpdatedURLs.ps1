#Requires -Version 5.1
<#
.SYNOPSIS
    Quick test for updated download URLs
#>

Write-Host "Testing Updated URLs" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Test Warp Terminal
Write-Host "`nTesting Warp Terminal..." -ForegroundColor Yellow
$url = "https://app.warp.dev/get_warp?package=exe_x86_64"
Write-Host "URL: $url" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Green
    
    # Check if it's actually an exe
    if ($response.Headers['Content-Type'] -match 'application/octet-stream|application/x-msdownload|application/exe') {
        Write-Host "SUCCESS: Returns executable file" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Unexpected content type" -ForegroundColor Yellow
    }
}
catch {
    if ($_.Exception.Response.StatusCode -eq 'MethodNotAllowed') {
        Write-Host "HEAD not allowed, trying small GET..." -ForegroundColor Yellow
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
            $fileInfo = Get-Item $tempFile
            Write-Host "Downloaded file size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
            
            # Check file signature
            $bytes = [System.IO.File]::ReadAllBytes($tempFile) | Select-Object -First 2
            $signature = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
            
            if ($signature -eq '4D5A') {
                Write-Host "SUCCESS: Valid EXE file (MZ header)" -ForegroundColor Green
            } else {
                Write-Host "WARNING: File signature: $signature" -ForegroundColor Yellow
            }
            
            Remove-Item $tempFile -Force
        }
        catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green