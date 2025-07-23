# Claude CLI Installation Script for Windows
# This script installs Claude CLI via npm and adds it to PATH

Write-Host "Claude CLI Installation Script" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js/npm is installed
Write-Host "Checking for Node.js/npm..." -ForegroundColor Yellow
try {
    $npmVersion = npm --version 2>$null
    if ($?) {
        Write-Host "npm found (version $npmVersion)" -ForegroundColor Green
    } else {
        throw "npm not found"
    }
} catch {
    Write-Host "npm is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Install Claude CLI globally
Write-Host "Installing Claude CLI..." -ForegroundColor Yellow
try {
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Claude CLI installed successfully" -ForegroundColor Green
    } else {
        throw "Installation failed"
    }
} catch {
    Write-Host "Failed to install Claude CLI" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get npm global directory
Write-Host "Configuring PATH..." -ForegroundColor Yellow
$npmGlobalDir = (npm config get prefix).Trim()
Write-Host "npm global directory: $npmGlobalDir" -ForegroundColor Gray

# Check if already in PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$npmGlobalDir*") {
    # Add to PATH
    $newPath = "$currentPath;$npmGlobalDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $npmGlobalDir to user PATH" -ForegroundColor Green
    
    # Update current session
    $env:Path = "$env:Path;$npmGlobalDir"
    Write-Host "Updated PATH for current session" -ForegroundColor Green
} else {
    Write-Host "npm global directory already in PATH" -ForegroundColor Green
}

Write-Host ""

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Yellow
try {
    $claudeVersion = claude --version 2>$null
    if ($?) {
        Write-Host "Claude CLI is working (version: $claudeVersion)" -ForegroundColor Green
    } else {
        throw "Claude command not found"
    }
} catch {
    Write-Host "Claude CLI installed but not immediately available" -ForegroundColor Yellow
    Write-Host "Please restart your terminal or run: `$env:Path = `"`$env:Path;$npmGlobalDir`"" -ForegroundColor Gray
}

Write-Host ""

# Run claude doctor
Write-Host "Running health check..." -ForegroundColor Yellow
try {
    claude doctor
    Write-Host "Health check completed" -ForegroundColor Green
} catch {
    Write-Host "Could not run health check - try restarting terminal" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Navigate to your project directory" -ForegroundColor White
Write-Host "2. Run 'claude' to start Claude Code" -ForegroundColor White
Write-Host "3. Authenticate using your preferred method" -ForegroundColor White
Write-Host ""
Write-Host "For more info: https://docs.anthropic.com/en/docs/claude-code" -ForegroundColor Gray