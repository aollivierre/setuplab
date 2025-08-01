# Test to prove the fix works

Write-Host "Testing current behavior (fails with empty string):" -ForegroundColor Yellow
$CustomInstallScript = ""

# Current check (line 650)
if (-not $CustomInstallScript) {
    Write-Host "  Current check caught it" -ForegroundColor Green
} else {
    Write-Host "  Current check MISSED it - empty string passed through!" -ForegroundColor Red
    try {
        # This is where it fails (line 654)
        if (-not (Test-Path $CustomInstallScript)) {
            Write-Host "  Test-Path would throw error here"
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

Write-Host "`nTesting fixed behavior:" -ForegroundColor Yellow
# Fixed check
if (-not $CustomInstallScript -or $CustomInstallScript.Trim() -eq '') {
    Write-Host "  Fixed check caught the empty string!" -ForegroundColor Green
} else {
    Write-Host "  Fixed check failed" -ForegroundColor Red
}

Write-Host "`nTesting with null:" -ForegroundColor Yellow
$CustomInstallScript = $null
if (-not $CustomInstallScript -or $CustomInstallScript.Trim() -eq '') {
    Write-Host "  Fixed check caught null too!" -ForegroundColor Green
}

Write-Host "`nTesting with valid path:" -ForegroundColor Yellow
$CustomInstallScript = "C:\test\script.ps1"
if (-not $CustomInstallScript -or $CustomInstallScript.Trim() -eq '') {
    Write-Host "  Fixed check incorrectly blocked valid path" -ForegroundColor Red
} else {
    Write-Host "  Fixed check correctly allowed valid path" -ForegroundColor Green
}