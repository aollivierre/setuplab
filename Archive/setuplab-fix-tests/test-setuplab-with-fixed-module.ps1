# TEST SETUPLAB WITH OUR FIXED MODULE
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING SETUPLAB WITH FIXED MODULE ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. PREPARING REMOTE ENVIRONMENT..." -ForegroundColor Cyan
    
    # Create directories and copy files
    Invoke-Command -Session $session -ScriptBlock {
        New-Item -Path "C:\temp\SetupLab-Fixed" -ItemType Directory -Force | Out-Null
        Write-Host "Created test directory" -ForegroundColor Green
    }
    
    # Copy all required files
    Write-Host "Copying fixed files to remote..." -ForegroundColor Yellow
    Copy-Item -Path "C:\code\setuplab\SetupLabCore.psm1" -Destination "C:\temp\SetupLab-Fixed\" -ToSession $session -Force
    Copy-Item -Path "C:\code\setuplab\SetupLabLogging.psm1" -Destination "C:\temp\SetupLab-Fixed\" -ToSession $session -Force
    Copy-Item -Path "C:\code\setuplab\main.ps1" -Destination "C:\temp\SetupLab-Fixed\" -ToSession $session -Force
    Copy-Item -Path "C:\code\setuplab\test-config-minimal.json" -Destination "C:\temp\SetupLab-Fixed\software-config.json" -ToSession $session -Force
    Copy-Item -Path "C:\code\setuplab\install-claude-cli.ps1" -Destination "C:\temp\SetupLab-Fixed\" -ToSession $session -Force
    
    Write-Host "Files copied successfully" -ForegroundColor Green
    
    Write-Host "`n2. RUNNING SETUPLAB WITH FIXED MODULE..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Change to our test directory
        Set-Location "C:\temp\SetupLab-Fixed"
        
        # Create log
        $logFile = "C:\temp\setuplab-fixed-test.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab with fixed module..." -ForegroundColor Yellow
        Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray
        
        try {
            # Run main.ps1 which will use our fixed module
            & ".\main.ps1"
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Stop-Transcript
        
        # Check results
        @{
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            GitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
            NodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
            LogFile = if (Test-Path $logFile) {
                Get-Content $logFile | Where-Object { $_ -match "Claude|Error|Failed|empty string" } | Select-Object -Last 20
            } else { @() }
        }
    }
    
    Write-Host "`n3. INSTALLATION RESULTS:" -ForegroundColor Cyan
    Write-Host "Git installed: $($result.GitInstalled)" -ForegroundColor $(if($result.GitInstalled){'Green'}else{'Red'})
    Write-Host "Node.js installed: $($result.NodeInstalled)" -ForegroundColor $(if($result.NodeInstalled){'Green'}else{'Red'})
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "Claude CLI installed: $($result.ClaudeInstalled)" -ForegroundColor $(if($result.ClaudeInstalled){'Green'}else{'Red'})
    
    if (-not $result.ClaudeInstalled -and $result.LogFile) {
        Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
        $result.LogFile | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    if ($result.ClaudeInstalled) {
        Write-Host "`nSUCCESS! The fix worked!" -ForegroundColor Green
        
        # Test Claude version
        $version = Invoke-Command -Session $session -ScriptBlock {
            cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        Write-Host "Claude version: $version" -ForegroundColor Green
    } else {
        Write-Host "`nFAILED! The bug is still present or there's another issue" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}