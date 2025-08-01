# TEST SETUPLAB FROM GITHUB WITH FIX
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING SETUPLAB FROM GITHUB WITH FIX ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Expected version: 2.1.0" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. RUNNING WEB LAUNCHER FROM GITHUB..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create directories
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        
        # Copy minimal config
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
        
        $configContent | Out-File -FilePath "C:\code\test-config-minimal.json" -Encoding UTF8
        $env:SETUPLAB_CONFIG_PATH = "C:\code\test-config-minimal.json"
        
        # Create log
        $logFile = "C:\code\github-fix-test.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab from GitHub with fix..." -ForegroundColor Yellow
        
        try {
            # Run the web launcher - it should show version 2.1.0
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
        
        # Check results
        @{
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            GitInstalled = Test-Path "C:\Program Files\Git\bin\git.exe"
            NodeInstalled = Test-Path "C:\Program Files\nodejs\node.exe"
            LogContent = if (Test-Path $logFile) {
                $content = Get-Content $logFile -Raw
                # Extract version info and errors
                $versionLine = $content | Select-String "SetupLab Web Launcher v" | Select-Object -First 1
                $errors = $content | Select-String "Claude|Error|Failed|empty string" | Select-Object -Last 20
                @{
                    Version = $versionLine
                    Errors = $errors
                }
            } else { @{} }
        }
    }
    
    Write-Host "`n2. RESULTS:" -ForegroundColor Cyan
    
    if ($result.LogContent.Version) {
        Write-Host "Web Launcher Version: $($result.LogContent.Version)" -ForegroundColor Yellow
    }
    
    Write-Host "`nInstallation Status:" -ForegroundColor Yellow
    Write-Host "Git installed: $($result.GitInstalled)" -ForegroundColor $(if($result.GitInstalled){'Green'}else{'Red'})
    Write-Host "Node.js installed: $($result.NodeInstalled)" -ForegroundColor $(if($result.NodeInstalled){'Green'}else{'Red'})
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "Claude CLI installed: $($result.ClaudeInstalled)" -ForegroundColor $(if($result.ClaudeInstalled){'Green'}else{'Red'})
    
    if ($result.ClaudeInstalled) {
        Write-Host "`nSUCCESS! The fix worked from GitHub!" -ForegroundColor Green
        
        # Test Claude version
        $version = Invoke-Command -Session $session -ScriptBlock {
            cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        Write-Host "Claude version: $version" -ForegroundColor Green
    } else {
        Write-Host "`nFAILED! Check errors below:" -ForegroundColor Red
        if ($result.LogContent.Errors) {
            Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
            $result.LogContent.Errors | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}