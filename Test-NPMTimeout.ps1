#Requires -Version 5.1
<#
.SYNOPSIS
    Test script to diagnose NPM timeout issues
.DESCRIPTION
    This script tests NPM installation with various timeout approaches
#>

Write-Host "Testing NPM Installation Methods" -ForegroundColor Cyan
Write-Host (("=" * 50)) -ForegroundColor Cyan

# Test 1: Direct NPM command with timeout
Write-Host "`nTest 1: Direct NPM with Start-Process timeout" -ForegroundColor Yellow
try {
    $npmCommand = "npm install -g @anthropic-ai/claude-code --ignore-scripts"
    Write-Host "Running: $npmCommand" -ForegroundColor White
    
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = "cmd.exe"
    $processStartInfo.Arguments = "/c $npmCommand"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    $process.Start() | Out-Null
    
    # Wait for process with timeout (30 seconds for testing)
    $timeoutMilliseconds = 30000
    if (-not $process.WaitForExit($timeoutMilliseconds)) {
        Write-Host "  TIMEOUT: NPM installation timed out after 30 seconds" -ForegroundColor Red
        $process.Kill()
        Write-Host "  Process killed successfully" -ForegroundColor Yellow
    } else {
        Write-Host "  SUCCESS: NPM installation completed" -ForegroundColor Green
        Write-Host "  Exit code: $($process.ExitCode)" -ForegroundColor White
    }
    
    # Get output
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    
    if ($stdout) {
        Write-Host "  STDOUT: $stdout" -ForegroundColor Gray
    }
    if ($stderr) {
        Write-Host "  STDERR: $stderr" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
}

# Test 2: Check if NPM is working at all
Write-Host "`nTest 2: NPM Version Check" -ForegroundColor Yellow
try {
    $npmVersion = & npm --version 2>&1
    Write-Host "  NPM Version: $npmVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: NPM not accessible - $_" -ForegroundColor Red
}

# Test 3: Check Node.js version
Write-Host "`nTest 3: Node.js Version Check" -ForegroundColor Yellow
try {
    $nodeVersion = & node --version 2>&1
    Write-Host "  Node.js Version: $nodeVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: Node.js not accessible - $_" -ForegroundColor Red
}

# Test 4: Check PATH
Write-Host "`nTest 4: PATH Analysis" -ForegroundColor Yellow
$pathEntries = $env:PATH -split ";"
$nodeRelatedPaths = $pathEntries | Where-Object { $_ -like "*node*" -or $_ -like "*npm*" }
if ($nodeRelatedPaths) {
    Write-Host "  Node.js related PATH entries:" -ForegroundColor Green
    $nodeRelatedPaths | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
} else {
    Write-Host "  No Node.js related PATH entries found" -ForegroundColor Yellow
}

# Test 5: Alternative approach with Invoke-Expression
Write-Host "`nTest 5: Alternative NPM approach" -ForegroundColor Yellow
try {
    $result = Invoke-Expression "npm --version" -ErrorAction Stop
    Write-Host "  NPM via Invoke-Expression: $result" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: Invoke-Expression failed - $_" -ForegroundColor Red
}

Write-Host "`n" + (("=" * 50)) -ForegroundColor Cyan
Write-Host "NPM Timeout Test Complete" -ForegroundColor Cyan