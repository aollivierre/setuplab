# Test what happens when Get-Module returns null

Write-Host "Testing module path resolution issue:" -ForegroundColor Yellow

# Simulate the condition
$installation = @{
    customInstallScript = "install-claude-cli.ps1"
}
$PSScriptRoot = $null

Write-Host "`nScenario: PSScriptRoot is null" -ForegroundColor Cyan
Write-Host "customInstallScript: $($installation.customInstallScript)"

# Try to get module (might be null in certain contexts)
$module = Get-Module SetupLabCore
Write-Host "Module found: $($null -ne $module)"

if ($module) {
    $moduleDir = Split-Path $module.Path -Parent
    Write-Host "Module directory: $moduleDir"
    $scriptPath = Join-Path $moduleDir $installation.customInstallScript
    Write-Host "Resolved path: $scriptPath"
} else {
    Write-Host "Module is NULL - THIS IS THE BUG!" -ForegroundColor Red
    # This is what happens:
    $moduleDir = Split-Path $null -Parent
    Write-Host "Split-Path of null returns: '$moduleDir'" -ForegroundColor Red
    $scriptPath = Join-Path $moduleDir $installation.customInstallScript
    Write-Host "Join-Path result: '$scriptPath'" -ForegroundColor Red
    Write-Host "Is scriptPath empty? $([string]::IsNullOrEmpty($scriptPath))" -ForegroundColor Red
}