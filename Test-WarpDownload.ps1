#Requires -Version 5.1
Write-Host "Testing Warp Download Methods" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Method 1: Direct URL
Write-Host "`nMethod 1: Direct URL Test" -ForegroundColor Yellow
$url = "https://app.warp.dev/get_warp?package=exe_x86_64"

try {
    # Allow redirects
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
    Write-Host "Initial Response: $($response.StatusCode)" -ForegroundColor Green
    
    if ($response.StatusCode -eq 302 -or $response.StatusCode -eq 301) {
        $redirectUrl = $response.Headers.Location
        Write-Host "Redirect to: $redirectUrl" -ForegroundColor Yellow
        
        # Follow redirect
        $response2 = Invoke-WebRequest -Uri $redirectUrl -UseBasicParsing
        Write-Host "Final Status: $($response2.StatusCode)" -ForegroundColor Green
    }
}
catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 302) {
        $redirectUrl = $_.Exception.Response.Headers.Location.AbsoluteUri
        Write-Host "Redirect found: $redirectUrl" -ForegroundColor Yellow
    } else {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

# Method 2: Check if winget is available
Write-Host "`nMethod 2: Checking winget availability" -ForegroundColor Yellow
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "Winget is available at: $($winget.Path)" -ForegroundColor Green
    Write-Host "You can install Warp using: winget install Warp.Warp" -ForegroundColor Green
} else {
    Write-Host "Winget is not available" -ForegroundColor Yellow
}

# Method 3: Try alternative endpoints
Write-Host "`nMethod 3: Testing alternative endpoints" -ForegroundColor Yellow
$alternatives = @(
    "https://app.warp.dev/download/win",
    "https://app.warp.dev/download/windows", 
    "https://releases.warp.dev/windows/stable"
)

foreach ($alt in $alternatives) {
    Write-Host "`nTrying: $alt" -ForegroundColor Gray
    try {
        $response = Invoke-WebRequest -Uri $alt -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "  Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Green
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}