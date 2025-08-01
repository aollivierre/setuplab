# RUN MINIMAL CONFIG TEST ON RESET MACHINE
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== RUNNING MINIMAL CONFIG TEST ON FRESH VM ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Config: Git, Node.js, Claude CLI only" -ForegroundColor Cyan

# Wait for system to be ready
Write-Host "`nWaiting for system to be ready..." -ForegroundColor Yellow
$ready = $false
$attempts = 0
while (-not $ready -and $attempts -lt 10) {
    $attempts++
    try {
        $test = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
        Remove-PSSession $test
        $ready = $true
    } catch {
        Start-Sleep -Seconds 3
    }
}

if (-not $ready) {
    Write-Host "System not ready after 30 seconds" -ForegroundColor Red
    return
}

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. COPYING MINIMAL CONFIG..." -ForegroundColor Cyan
    
    # First create the config file on remote
    Invoke-Command -Session $session -ScriptBlock {
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
        
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        $configContent | Out-File -FilePath "C:\code\test-config-minimal.json" -Encoding UTF8
        Write-Host "Config file created: C:\code\test-config-minimal.json" -ForegroundColor Green
    }
    
    Write-Host "`n2. RUNNING WEB LAUNCHER WITH MINIMAL CONFIG..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create log file to capture everything
        $logFile = "C:\code\minimal-test-log.txt"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "Starting SetupLab with minimal config..." -ForegroundColor Green
        
        # Run the web launcher with config file
        try {
            $env:SETUPLAB_CONFIG_PATH = "C:\code\test-config-minimal.json"
            Write-Host "Config path set to: $env:SETUPLAB_CONFIG_PATH" -ForegroundColor Yellow
            
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        } catch {
            Write-Host "ERROR IN WEB LAUNCHER: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
        
        # Return key info
        @{
            LogCreated = Test-Path $logFile
            ConfigExists = Test-Path "C:\code\test-config-minimal.json"
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
        }
    }
    
    # Wait for completion - minimal config should be faster
    Write-Host "`n3. Waiting for installation to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 90  # 1.5 minutes for just 3 components
    
    Write-Host "`n4. CHECKING RESULTS..." -ForegroundColor Cyan
    
    $finalResult = Invoke-Command -Session $session -ScriptBlock {
        $result = @{
            # Component status
            GitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
            NodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
            ClaudeCmd = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDir = Test-Path "$env:APPDATA\npm"
            
            # Get the error from log
            LogContent = if (Test-Path "C:\code\minimal-test-log.txt") {
                Get-Content "C:\code\minimal-test-log.txt" | Where-Object { $_ -match "Claude|Cannot bind|empty string|Failed to install|CUSTOM" } | Select-Object -Last 50
            } else { @() }
            
            # Get SetupLab logs
            SetupLabLogs = @()
        }
        
        # Find SetupLab logs
        $logPaths = @(
            "C:\ProgramData\SetupLab\Logs\*.txt",
            "$env:TEMP\SetupLab_*\Logs\*.txt"
        )
        
        foreach ($path in $logPaths) {
            $files = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($files) {
                $content = Get-Content $files.FullName | Where-Object { $_ -match "Claude|CUSTOM" }
                if ($content) {
                    $result.SetupLabLogs += $content
                }
            }
        }
        
        return $result
    }
    
    Write-Host "`n=== RESULTS ===" -ForegroundColor Red
    Write-Host "Git installed: $($finalResult.GitInstalled)" -ForegroundColor $(if($finalResult.GitInstalled){'Green'}else{'Red'})
    Write-Host "Node.js installed: $($finalResult.NodeInstalled)" -ForegroundColor $(if($finalResult.NodeInstalled){'Green'}else{'Red'})
    Write-Host "npm directory exists: $($finalResult.NpmDir)" -ForegroundColor $(if($finalResult.NpmDir){'Green'}else{'Red'})
    Write-Host "Claude installed: $($finalResult.ClaudeCmd)" -ForegroundColor $(if($finalResult.ClaudeCmd){'Green'}else{'Red'})
    
    if (-not $finalResult.ClaudeCmd) {
        Write-Host "`nCLAUDE INSTALLATION FAILED!" -ForegroundColor Red
        
        if ($finalResult.LogContent) {
            Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
            $finalResult.LogContent | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        if ($finalResult.SetupLabLogs) {
            Write-Host "`nSetupLab CUSTOM entries:" -ForegroundColor Yellow
            $finalResult.SetupLabLogs | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        Write-Host "`nTHE ISSUE:" -ForegroundColor Red
        Write-Host "Look for 'Cannot bind argument to parameter Path because it is an empty string'" -ForegroundColor Red
        Write-Host "This happens in SetupLabCore.psm1 when processing CUSTOM installers" -ForegroundColor Red
        Write-Host "Check lines 649-688 and 1080-1127 in SetupLabCore.psm1" -ForegroundColor Red
    } else {
        Write-Host "`nSUCCESS! Claude installed correctly with minimal config!" -ForegroundColor Green
        
        # Get version if successful
        $version = Invoke-Command -Session $session -ScriptBlock {
            cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        Write-Host "Claude version: $version" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}