# Claude CLI Installation Script for Windows
# This script installs Claude CLI via npm and adds it to PATH

Write-Host "Claude CLI Installation Script" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js/npm is installed
Write-Host "Checking for Node.js/npm..." -ForegroundColor Yellow
$npmCmd = $null
$npmVersion = $null

# First try npm in PATH
try {
    $npmVersion = npm --version 2>$null
    if ($?) {
        $npmCmd = "npm"
        Write-Host "npm found in PATH (version $npmVersion)" -ForegroundColor Green
    }
} catch {}

# If not in PATH, check common Node.js installation locations
if (-not $npmCmd) {
    Write-Host "npm not found in PATH, checking Node.js installation..." -ForegroundColor Yellow
    
    $nodePaths = @(
        "C:\Program Files\nodejs\npm.cmd",
        "C:\Program Files (x86)\nodejs\npm.cmd",
        "$env:ProgramFiles\nodejs\npm.cmd",
        "${env:ProgramFiles(x86)}\nodejs\npm.cmd"
    )
    
    foreach ($path in $nodePaths) {
        if (Test-Path $path) {
            Write-Host "Found npm at: $path" -ForegroundColor Green
            $npmCmd = "`"$path`""
            
            # Get version using full path
            try {
                $npmVersion = & cmd /c "`"$path`" --version 2>&1"
                Write-Host "npm version: $npmVersion" -ForegroundColor Green
            } catch {
                Write-Host "Could not get npm version" -ForegroundColor Yellow
            }
            break
        }
    }
}

# If still not found, check if Node.js was just installed
if (-not $npmCmd) {
    # Check registry for Node.js installation
    $nodeRegPaths = @(
        "HKLM:\SOFTWARE\Node.js",
        "HKLM:\SOFTWARE\WOW6432Node\Node.js"
    )
    
    foreach ($regPath in $nodeRegPaths) {
        if (Test-Path $regPath) {
            try {
                $installPath = (Get-ItemProperty -Path $regPath -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
                if ($installPath) {
                    $npmPath = Join-Path $installPath "npm.cmd"
                    if (Test-Path $npmPath) {
                        Write-Host "Found npm via registry at: $npmPath" -ForegroundColor Green
                        $npmCmd = "`"$npmPath`""
                        break
                    }
                }
            } catch {}
        }
    }
}

if (-not $npmCmd) {
    Write-Host "npm is not installed or cannot be found" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Install Claude CLI globally
Write-Host "Installing Claude CLI..." -ForegroundColor Yellow
Write-Host "Using npm command: $npmCmd" -ForegroundColor Gray

try {
    # Use cmd.exe to ensure proper execution with full paths
    $installCmd = "$npmCmd install -g @anthropic-ai/claude-code"
    Write-Host "Running: $installCmd" -ForegroundColor Gray
    
    $output = & cmd /c $installCmd 2>&1
    Write-Host $output
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Claude CLI installed successfully" -ForegroundColor Green
    } else {
        throw "Installation failed with exit code: $LASTEXITCODE"
    }
} catch {
    Write-Host "Failed to install Claude CLI: $_" -ForegroundColor Red
    
    # Try alternative: spawn new PowerShell session where PATH is refreshed
    Write-Host "`nTrying alternative method with new PowerShell session..." -ForegroundColor Yellow
    
    $scriptBlock = {
        # Force PATH refresh
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Now try npm again
        npm install -g @anthropic-ai/claude-code
        exit $LASTEXITCODE
    }
    
    $result = Start-Process powershell -ArgumentList "-NoProfile", "-Command", $scriptBlock -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -eq 0) {
        Write-Host "Claude CLI installed successfully using alternative method" -ForegroundColor Green
    } else {
        Write-Host "Installation failed even with alternative method" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Get npm global directory
Write-Host "Configuring PATH..." -ForegroundColor Yellow
$npmGlobalDir = (& cmd /c "$npmCmd config get prefix" 2>$null).Trim()

# Validate npm global directory
if (-not $npmGlobalDir) {
    Write-Host "Failed to get npm global directory" -ForegroundColor Red
    exit 1
}

Write-Host "npm global directory: $npmGlobalDir" -ForegroundColor Gray

# Ensure npm global directory exists
if (-not (Test-Path $npmGlobalDir)) {
    Write-Host "Creating npm global directory: $npmGlobalDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $npmGlobalDir -Force | Out-Null
}

# Check if already in PATH
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $currentPath) {
        Write-Host "User PATH is empty or null, initializing..." -ForegroundColor Yellow
        $currentPath = ""
    }
} catch {
    Write-Host "Warning: Could not get user PATH: $_" -ForegroundColor Yellow
    $currentPath = ""
}

if ($currentPath -notlike "*$npmGlobalDir*") {
    # Add to PATH
    $newPath = if ($currentPath) { "$currentPath;$npmGlobalDir" } else { $npmGlobalDir }
    
    try {
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Added $npmGlobalDir to user PATH" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not set user PATH: $_" -ForegroundColor Yellow
        Write-Host "Attempting alternative method..." -ForegroundColor Yellow
        
        # Try using registry directly as fallback
        try {
            $regPath = "HKCU:\Environment"
            Set-ItemProperty -Path $regPath -Name "Path" -Value $newPath
            Write-Host "Updated PATH via registry" -ForegroundColor Green
        } catch {
            Write-Host "Failed to update PATH: $_" -ForegroundColor Red
            # Continue anyway - installation might still work
        }
    }
    
    # Update current session
    $env:Path = "$env:Path;$npmGlobalDir"
    Write-Host "Updated PATH for current session" -ForegroundColor Green
} else {
    Write-Host "npm global directory already in PATH" -ForegroundColor Green
}

Write-Host ""

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Yellow
$claudeFound = $false

# First try claude in PATH
try {
    $claudeVersion = claude --version 2>$null
    if ($?) {
        Write-Host "Claude CLI is working (version: $claudeVersion)" -ForegroundColor Green
        $claudeFound = $true
    }
} catch {}

# If not in PATH, try direct path
if (-not $claudeFound) {
    $claudePath = Join-Path $npmGlobalDir "claude.cmd"
    if (Test-Path $claudePath) {
        try {
            $claudeVersion = & cmd /c "`"$claudePath`" --version" 2>$null
            if ($claudeVersion) {
                Write-Host "Claude CLI installed at: $claudePath" -ForegroundColor Green
                Write-Host "Version: $claudeVersion" -ForegroundColor Green
                $claudeFound = $true
            }
        } catch {}
    }
}

if (-not $claudeFound) {
    Write-Host "Claude CLI installed but not immediately available" -ForegroundColor Yellow
    Write-Host "Please restart your terminal or run: `$env:Path = `"`$env:Path;$npmGlobalDir`"" -ForegroundColor Gray
}

Write-Host ""

# Run claude doctor
if ($claudeFound) {
    Write-Host "Running health check..." -ForegroundColor Yellow
    try {
        if ($claudePath -and (Test-Path $claudePath)) {
            & cmd /c "`"$claudePath`" doctor"
        } else {
            claude doctor
        }
        Write-Host "Health check completed" -ForegroundColor Green
    } catch {
        Write-Host "Could not run health check - try restarting terminal" -ForegroundColor Yellow
    }
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