# Test the new web launcher on remote Windows 11 machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Testing new web launcher on $RemoteComputer..." -ForegroundColor Yellow

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $RemoteComputer" -ForegroundColor Green
    
    # Run the web launcher
    Write-Host "`nRunning web launcher with new cache busting..." -ForegroundColor Yellow
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Set execution policy
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Clear any DNS cache
            ipconfig /flushdns | Out-Null
            
            # Run the web launcher
            $output = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
            
            # Get the last 100 lines of output
            $lines = $output -split "`n"
            $lastLines = if ($lines.Count -gt 100) { $lines[-100..-1] } else { $lines }
            
            # Check for specific outcomes
            $claudeSuccess = $output -match "Claude CLI installed successfully"
            $claudeFailed = $output -match "Failed to install Claude CLI"
            $versionInfo = $output -match "SetupLab Web Launcher v"
            
            return @{
                Success = $true
                Output = $lastLines -join "`n"
                ClaudeInstalled = $claudeSuccess
                ClaudeFailed = $claudeFailed
                VersionDetected = $versionInfo
            }
        }
        catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
        }
    }
    
    # Display results
    Write-Host "`nResults:" -ForegroundColor Cyan
    
    if ($result.Success) {
        if ($result.VersionDetected) {
            Write-Host "[OK] New version detected in output" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Version info not found" -ForegroundColor Red
        }
        
        if ($result.ClaudeInstalled) {
            Write-Host "[OK] Claude CLI installed successfully!" -ForegroundColor Green
        } elseif ($result.ClaudeFailed) {
            Write-Host "[FAIL] Claude CLI installation failed" -ForegroundColor Red
        } else {
            Write-Host "? Claude CLI status unknown" -ForegroundColor Yellow
        }
        
        Write-Host "`nLast 100 lines of output:" -ForegroundColor Yellow
        Write-Host $result.Output
    }
    else {
        Write-Host "Web launcher failed!" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
    }
    
    # Additional verification
    Write-Host "`n`nVerifying Claude CLI installation..." -ForegroundColor Yellow
    $verification = Invoke-Command -Session $session -ScriptBlock {
        $claudePath = "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
        $exists = Test-Path $claudePath
        
        $version = $null
        if ($exists) {
            try {
                $version = cmd /c "claude --version 2>&1"
            } catch {
                $version = "Could not get version"
            }
        }
        
        return @{
            Exists = $exists
            Path = $claudePath
            Version = $version
        }
    }
    
    Write-Host "`nClaude CLI Verification:" -ForegroundColor Cyan
    Write-Host "  Exists: $($verification.Exists)"
    Write-Host "  Path: $($verification.Path)"
    if ($verification.Version) {
        Write-Host "  Version: $($verification.Version)"
    }
    
    # Clean up
    Remove-PSSession -Session $session
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}