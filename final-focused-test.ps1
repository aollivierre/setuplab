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
    
    Write-Host "`n1. Setting up minimal config and running web launcher..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create directory
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        
        # Create minimal config with ONLY 3 components
        $configContent = @'
{
    "configurations": {
        "skipValidation": false,
        "maxConcurrency": 1,
        "logLevel": "Debug"
    },
    "systemConfigurations": [],
    "software": [
        {
            "name": "Git",
            "enabled": true,
            "registryName": "Git",
            "executablePath": "C:\\Program Files\\Git\\bin\\git.exe",
            "downloadUrl": "https://github.com/git-for-windows/git/releases/download/v2.50.1.windows.1/Git-2.50.1-64-bit.exe",
            "installerExtension": ".exe",
            "installType": "EXE",
            "installArguments": [
                "/VERYSILENT",
                "/NORESTART",
                "/NOCANCEL",
                "/SP-",
                "/CLOSEAPPLICATIONS",
                "/RESTARTAPPLICATIONS",
                "/COMPONENTS=icons,ext\\reg\\shellhere,assoc,assoc_sh"
            ],
            "minimumVersion": "2.40.0",
            "category": "Development"
        },
        {
            "name": "Node.js",
            "enabled": true,
            "registryName": "Node.js",
            "executablePath": "C:\\Program Files\\nodejs\\node.exe",
            "downloadUrl": "https://nodejs.org/dist/v22.17.1/node-v22.17.1-x64.msi",
            "installerExtension": ".msi",
            "installType": "MSI",
            "installArguments": [],
            "minimumVersion": "20.0.0",
            "category": "Development",
            "postInstallCommand": "setx PATH \"%PATH%;%ProgramFiles%\\nodejs\\\" /M"
        },
        {
            "name": "Claude Code (CLI)",
            "enabled": true,
            "registryName": null,
            "executablePath": "%APPDATA%\\npm\\claude.cmd",
            "downloadUrl": null,
            "installerExtension": null,
            "installType": "CUSTOM",
            "installArguments": [],
            "minimumVersion": null,
            "category": "Development",
            "customInstallScript": "install-claude-cli.ps1",
            "dependencies": ["Git", "Node.js"]
        }
    ]
}
'@
        
        $configContent | Out-File -FilePath "C:\code\minimal-config.json" -Encoding UTF8
        $env:SETUPLAB_CONFIG_PATH = "C:\code\minimal-config.json"
        Write-Host "Config set to: $env:SETUPLAB_CONFIG_PATH" -ForegroundColor Yellow
        
        # Create log
        $logFile = "C:\code\final-focused-test.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab with ONLY 3 components..." -ForegroundColor Yellow
        
        try {
            # Run web launcher - should use our minimal config
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
        
        # Wait a moment for npm path to update
        Start-Sleep -Seconds 5
        
        # Check results
        @{
            # Component status
            GitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
            NodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            
            # Version info
            GitVersion = if (Test-Path "C:\Program Files\Git\bin\git.exe") {
                & "C:\Program Files\Git\bin\git.exe" --version 2>&1
            } else { "Not installed" }
            
            NodeVersion = if (Test-Path "C:\Program Files\nodejs\node.exe") {
                & "C:\Program Files\nodejs\node.exe" --version 2>&1
            } else { "Not installed" }
            
            ClaudeVersion = if (Test-Path "$env:APPDATA\npm\claude.cmd") {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            } else { "Not installed" }
            
            # Extract key log entries
            LogEntries = if (Test-Path $logFile) {
                $content = Get-Content $logFile
                @{
                    WebLauncherVersion = $content | Select-String "SetupLab Web Launcher v" | Select-Object -First 1
                    ClaudeEntries = $content | Select-String "Claude" | Select-Object -Last 10
                    ErrorEntries = $content | Select-String "Error|Failed|empty string" | Select-Object -Last 10
                }
            } else { @{} }
        }
    }
    
    Write-Host "`n2. RESULTS:" -ForegroundColor Cyan
    
    # Show web launcher version
    if ($result.LogEntries.WebLauncherVersion) {
        Write-Host "`nWeb Launcher: $($result.LogEntries.WebLauncherVersion)" -ForegroundColor Yellow
    }
    
    # Installation status
    Write-Host "`nComponent Status:" -ForegroundColor Yellow
    Write-Host "1. Git installed: $($result.GitInstalled)" -ForegroundColor $(if($result.GitInstalled){'Green'}else{'Red'})
    if ($result.GitInstalled) {
        Write-Host "   Version: $($result.GitVersion)" -ForegroundColor Gray
    }
    
    Write-Host "2. Node.js installed: $($result.NodeInstalled)" -ForegroundColor $(if($result.NodeInstalled){'Green'}else{'Red'})
    if ($result.NodeInstalled) {
        Write-Host "   Version: $($result.NodeVersion)" -ForegroundColor Gray
    }
    
    Write-Host "3. npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    
    Write-Host "4. Claude CLI installed: $($result.ClaudeInstalled)" -ForegroundColor $(if($result.ClaudeInstalled){'Green'}else{'Red'})
    if ($result.ClaudeInstalled) {
        Write-Host "   Version: $($result.ClaudeVersion)" -ForegroundColor Gray
    }
    
    # Final verdict
    if ($result.GitInstalled -and $result.NodeInstalled -and $result.ClaudeInstalled) {
        Write-Host "`n[OK] SUCCESS! All 3 components installed correctly!" -ForegroundColor Green
        Write-Host "The fix worked!" -ForegroundColor Green
    } else {
        Write-Host "`n[FAIL] FAILED! Not all components installed" -ForegroundColor Red
        
        if ($result.LogEntries.ErrorEntries) {
            Write-Host "`nError entries:" -ForegroundColor Yellow
            $result.LogEntries.ErrorEntries | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        if ($result.LogEntries.ClaudeEntries) {
            Write-Host "`nClaude-related entries:" -ForegroundColor Yellow
            $result.LogEntries.ClaudeEntries | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}