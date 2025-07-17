#Requires -Version 5.1
Write-Host "Testing Final URLs" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

$urls = @(
    @{
        Name = "FileLocator Pro"
        URL = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
    },
    @{
        Name = "Warp Terminal"
        URL = "https://releases.warp.dev/stable/v0.2025.07.09.08.11.stable_01/WarpSetup.exe"
    }
)

foreach ($test in $urls) {
    Write-Host "`nTesting: $($test.Name)" -ForegroundColor Yellow
    Write-Host "URL: $($test.URL)" -ForegroundColor Gray
    
    try {
        # Enable TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Test with HEAD request
        $response = Invoke-WebRequest -Uri $test.URL -Method Head -UseBasicParsing -TimeoutSec 10
        Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "  Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Green
        
        if ($response.Headers['Content-Length']) {
            $sizeMB = [math]::Round([int64]$response.Headers['Content-Length'] / 1MB, 2)
            Write-Host "  File Size: $sizeMB MB" -ForegroundColor Green
        }
        
        Write-Host "  SUCCESS!" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 'MethodNotAllowed') {
            Write-Host "  HEAD not allowed, but URL exists" -ForegroundColor Yellow
            Write-Host "  Likely SUCCESS" -ForegroundColor Yellow
        } else {
            Write-Host "  ERROR: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green