# FINAL FOCUSED TEST - ONLY GIT, NODE.JS, AND CLAUDE CLI
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== FINAL FOCUSED TEST - 3 COMPONENTS ONLY ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Testing: Git, Node.js, Claude CLI ONLY" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. Running web launcher with minimal config..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create log
        $logFile = "C:\code\focused-test.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab - expecting version 2.1.0..." -ForegroundColor Yellow
        
        try {
            # Run web launcher with minimal config
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1' -UseBasicParsing) -Software @("Git", "Node.js", "Claude Code (CLI)")
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
    }
    
    # Wait for installation to complete
    Write-Host "`n2. Waiting for installation to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120
    
    Write-Host "`n3. Checking results..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        @{
            GitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
            NodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            ClaudeVersion = if (Test-Path "$env:APPDATA\npm\claude.cmd") {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            } else { "Not installed" }
        }
    }
    
    Write-Host "`nRESULTS:" -ForegroundColor Yellow
    Write-Host "Git installed: $($result.GitInstalled)" -ForegroundColor $(if($result.GitInstalled){'Green'}else{'Red'})
    Write-Host "Node.js installed: $($result.NodeInstalled)" -ForegroundColor $(if($result.NodeInstalled){'Green'}else{'Red'})
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "Claude CLI installed: $($result.ClaudeInstalled)" -ForegroundColor $(if($result.ClaudeInstalled){'Green'}else{'Red'})
    
    if ($result.ClaudeInstalled) {
        Write-Host "`nSUCCESS! Claude version: $($result.ClaudeVersion)" -ForegroundColor Green
    } else {
        Write-Host "`nFAILED! Claude was not installed" -ForegroundColor Red
        
        # Get the log
        $log = Invoke-Command -Session $session -ScriptBlock {
            if (Test-Path "C:\code\focused-test.log") {
                Get-Content "C:\code\focused-test.log" | Select-String "Claude|Error|Failed|empty string" | Select-Object -Last 20
            }
        }
        
        if ($log) {
            Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
            $log | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Connection error: $_" -ForegroundColor Red
}