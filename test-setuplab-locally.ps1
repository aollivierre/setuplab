# Simple local test script for SetupLab - Git, Node.js, and Claude CLI only
# This script runs SetupLab locally with comprehensive logging

param(
    [switch]$UseGitHub = $false
)

Write-Host "`n=== SetupLab Local Test - 3 Components Only ===" -ForegroundColor Cyan
Write-Host "Testing: Git, Node.js, Claude CLI" -ForegroundColor Yellow
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

# Create test directory
$testDir = "C:\temp\setuplab-test"
if (-not (Test-Path $testDir)) {
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null
}

# Create minimal configuration
$config = @{
    configurations = @{
        skipValidation = $false
        maxConcurrency = 1
        logLevel = "Debug"
    }
    systemConfigurations = @()
    software = @(
        @{
            name = "Git"
            enabled = $true
            registryName = "Git"
            executablePath = "C:\Program Files\Git\bin\git.exe"
            downloadUrl = "https://github.com/git-for-windows/git/releases/download/v2.50.1.windows.1/Git-2.50.1-64-bit.exe"
            installerExtension = ".exe"
            installType = "EXE"
            installArguments = @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS", "/COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh")
            minimumVersion = "2.40.0"
            category = "Development"
        },
        @{
            name = "Node.js"
            enabled = $true
            registryName = "Node.js"
            executablePath = "C:\Program Files\nodejs\node.exe"
            downloadUrl = "https://nodejs.org/dist/v22.17.1/node-v22.17.1-x64.msi"
            installerExtension = ".msi"
            installType = "MSI"
            installArguments = @()
            minimumVersion = "20.0.0"
            category = "Development"
            postInstallCommand = 'setx PATH "%PATH%;%ProgramFiles%\nodejs\" /M'
        },
        @{
            name = "Claude Code (CLI)"
            enabled = $true
            registryName = $null
            executablePath = "%APPDATA%\npm\claude.cmd"
            downloadUrl = $null
            installerExtension = $null
            installType = "CUSTOM"
            installArguments = @()
            minimumVersion = $null
            category = "Development"
            customInstallScript = "install-claude-cli.ps1"
            dependencies = @("Git", "Node.js")
        }
    )
}

$configPath = Join-Path $testDir "test-config.json"
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "`nConfig saved to: $configPath" -ForegroundColor Gray

if ($UseGitHub) {
    Write-Host "`nRunning SetupLab from GitHub..." -ForegroundColor Yellow
    $env:SETUPLAB_CONFIG_PATH = $configPath
    
    # Run from GitHub
    iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
}
else {
    Write-Host "`nRunning SetupLab locally..." -ForegroundColor Yellow
    
    # Import local module
    $modulePath = Join-Path $PSScriptRoot "SetupLabCore.psm1"
    if (-not (Test-Path $modulePath)) {
        Write-Host "ERROR: SetupLabCore.psm1 not found at: $modulePath" -ForegroundColor Red
        exit 1
    }
    
    Import-Module $modulePath -Force
    
    # Run installation
    $result = Start-SerialInstallation -Installations $config.software
    
    Write-Host "`n=== RESULTS ===" -ForegroundColor Yellow
    Write-Host "Completed: $($result.Completed.Count)" -ForegroundColor Green
    Write-Host "Failed: $($result.Failed.Count)" -ForegroundColor Red
    Write-Host "Skipped: $($result.Skipped.Count)" -ForegroundColor Gray
    
    # Check specific components
    Write-Host "`nComponent Status:" -ForegroundColor Cyan
    $gitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
    $nodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
    $claudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
    
    Write-Host "Git: $(if($gitInstalled){'INSTALLED'}else{'NOT FOUND'})" -ForegroundColor $(if($gitInstalled){'Green'}else{'Red'})
    Write-Host "Node.js: $(if($nodeInstalled){'INSTALLED'}else{'NOT FOUND'})" -ForegroundColor $(if($nodeInstalled){'Green'}else{'Red'})
    Write-Host "Claude CLI: $(if($claudeInstalled){'INSTALLED'}else{'NOT FOUND'})" -ForegroundColor $(if($claudeInstalled){'Green'}else{'Red'})
    
    if ($claudeInstalled) {
        Write-Host "`nClaude version:" -ForegroundColor Yellow
        & "$env:APPDATA\npm\claude.cmd" --version
    }
    
    # Show log location
    $logDir = Join-Path $PSScriptRoot "Logs"
    Write-Host "`nLooking for logs in: $logDir" -ForegroundColor Gray
    
    # Get today's log file
    $todayLog = "SetupLab_$(Get-Date -Format 'yyyyMMdd').log"
    $todayLogPath = Join-Path $logDir $todayLog
    
    if (Test-Path $todayLogPath) {
        Write-Host "Today's log file: $todayLogPath" -ForegroundColor Yellow
        Write-Host "Opening log file in notepad..." -ForegroundColor Gray
        Start-Process notepad.exe -ArgumentList $todayLogPath
    }
    
    # Also show latest log if different
    $latestLog = Get-ChildItem $logDir -Filter "SetupLab_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog -and $latestLog.Name -ne $todayLog) {
        Write-Host "Latest log file: $($latestLog.FullName)" -ForegroundColor Gray
    }
}