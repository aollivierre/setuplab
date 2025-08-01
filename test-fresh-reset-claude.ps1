# Test Claude installation on freshly reset system
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n[REFRESH] TESTING ON FRESHLY RESET SYSTEM [REFRESH]" -ForegroundColor Cyan
Write-Host "=====================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # First check the fresh state
    Write-Host "1. Checking fresh system state..." -ForegroundColor Yellow
    $freshState = Invoke-Command -Session $session -ScriptBlock {
        @{
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            NodeVersion = cmd /c "node --version 2>&1"
            NpmVersion = cmd /c "npm --version 2>&1"
        }
    }
    
    Write-Host "   npm directory exists: $($freshState.NpmDirExists)" -ForegroundColor Gray
    Write-Host "   claude.cmd exists: $($freshState.ClaudeExists)" -ForegroundColor Gray
    Write-Host "   Node.js version: $($freshState.NodeVersion)" -ForegroundColor Gray
    Write-Host "   npm version: $($freshState.NpmVersion)" -ForegroundColor Gray
    
    # Run the web launcher
    Write-Host "`n2. Running SetupLab Web Launcher..." -ForegroundColor Yellow
    Write-Host "   This should install all 16 applications including Claude Code" -ForegroundColor Gray
    
    $installResult = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Run web launcher
        $output = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
        
        # Extract key information
        $claudeLines = $output | Where-Object { $_ -match "Claude|install-claude-cli" } | Out-String
        $summaryLines = $output | Where-Object { $_ -match "Installation Summary:|Completed:|Failed:|Skipped:" } | Out-String
        
        @{
            ClaudeOutput = $claudeLines
            Summary = $summaryLines
        }
    }
    
    Write-Host "`n3. Installation Summary:" -ForegroundColor Yellow
    Write-Host $installResult.Summary -ForegroundColor Gray
    
    Write-Host "`n4. Claude-specific output:" -ForegroundColor Yellow
    Write-Host $installResult.ClaudeOutput -ForegroundColor Gray
    
    # Final verification
    Write-Host "`n5. Final Claude verification..." -ForegroundColor Yellow
    $finalCheck = Invoke-Command -Session $session -ScriptBlock {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        @{
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeExists = Test-Path $claudePath
            ClaudeVersion = if (Test-Path $claudePath) {
                cmd /c "`"$claudePath`" --version 2>&1"
            } else {
                "Not installed"
            }
        }
    }
    
    Write-Host "   npm directory exists: $($finalCheck.NpmDirExists)" -ForegroundColor $(if($finalCheck.NpmDirExists){'Green'}else{'Red'})
    Write-Host "   claude.cmd exists: $($finalCheck.ClaudeExists)" -ForegroundColor $(if($finalCheck.ClaudeExists){'Green'}else{'Red'})
    Write-Host "   Claude version: $($finalCheck.ClaudeVersion)" -ForegroundColor $(if($finalCheck.ClaudeVersion -match "Claude Code"){'Green'}else{'Red'})
    
    if ($finalCheck.ClaudeExists -and $finalCheck.ClaudeVersion -match "Claude Code") {
        Write-Host "`n[DONE] SUCCESS! Claude Code installed successfully on fresh system!" -ForegroundColor Green
        Write-Host "The fix is working perfectly!" -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] FAILED! Claude Code did not install properly" -ForegroundColor Red
        Write-Host "Further investigation needed" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}