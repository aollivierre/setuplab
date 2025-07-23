# Claude CLI Uninstallation Script for Windows
# This script removes Claude CLI installed via npm

Write-Host "Claude CLI Uninstallation Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if Claude CLI is installed
Write-Host "Checking for Claude CLI installation..." -ForegroundColor Yellow
try {
    $claudeVersion = claude --version 2>$null
    if ($?) {
        Write-Host "Found Claude CLI version: $claudeVersion" -ForegroundColor Green
    } else {
        throw "Claude CLI not found"
    }
} catch {
    Write-Host "Claude CLI is not installed" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Confirm uninstallation
$confirmation = Read-Host "Are you sure you want to uninstall Claude CLI? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Uninstallation cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Uninstall Claude CLI
Write-Host "Uninstalling Claude CLI..." -ForegroundColor Yellow
try {
    npm uninstall -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Claude CLI uninstalled successfully" -ForegroundColor Green
    } else {
        throw "Uninstallation failed"
    }
} catch {
    Write-Host "Failed to uninstall Claude CLI" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: The PATH environment variable has not been modified." -ForegroundColor Yellow
Write-Host "You may want to manually remove npm's global directory from PATH if not needed." -ForegroundColor Gray