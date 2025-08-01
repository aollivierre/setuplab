# TEST ONLY 3 COMPONENTS - USING CUSTOM CONFIG
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING 3 COMPONENTS ONLY ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Components: Git, Node.js, Claude CLI" -ForegroundColor Cyan
Write-Host "Expected web launcher version: 2.1.0" -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. Running SetupLab with custom config..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create directory
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        
        # Create config with ONLY 3 components
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
        
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath "C:\code\test-config.json" -Encoding UTF8
        
        # Set environment variable to use our config
        $env:SETUPLAB_CONFIG_PATH = "C:\code\test-config.json"
        
        # Create log
        $logFile = "C:\code\test-3-components.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab from GitHub..." -ForegroundColor Yellow
        Write-Host "Config path: $env:SETUPLAB_CONFIG_PATH" -ForegroundColor Gray
        
        try {
            # Run web launcher - it will use our config
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
    }
    
    # Wait for installation
    Write-Host "`n2. Waiting for installation to complete (2 minutes)..." -ForegroundColor Yellow
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
            
            LogContent = if (Test-Path "C:\code\test-3-components.log") {
                $content = Get-Content "C:\code\test-3-components.log" -Raw
                @{
                    Version = ($content | Select-String "SetupLab Web Launcher v(\d+\.\d+\.\d+)" | Select-Object -First 1).Matches[0].Groups[1].Value
                    ClaudeErrors = $content | Select-String "Claude.*Failed|Claude.*Error|empty string" | Select-Object -Last 10
                    Summary = $content | Select-String "Installation Summary:|Completed:|Failed:" | Select-Object -Last 10
                }
            } else { @{} }
        }
    }
    
    Write-Host "`nRESULTS:" -ForegroundColor Yellow
    Write-Host "Web Launcher Version: $($result.LogContent.Version)" -ForegroundColor Cyan
    Write-Host "`nComponents:" -ForegroundColor Yellow
    Write-Host "1. Git: $($result.GitInstalled)" -ForegroundColor $(if($result.GitInstalled){'Green'}else{'Red'})
    Write-Host "2. Node.js: $($result.NodeInstalled)" -ForegroundColor $(if($result.NodeInstalled){'Green'}else{'Red'})
    Write-Host "3. npm dir: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "4. Claude CLI: $($result.ClaudeInstalled)" -ForegroundColor $(if($result.ClaudeInstalled){'Green'}else{'Red'})
    
    if ($result.ClaudeInstalled) {
        Write-Host "`n✓ SUCCESS! Claude version: $($result.ClaudeVersion)" -ForegroundColor Green
        Write-Host "The fix worked!" -ForegroundColor Green
    } else {
        Write-Host "`n✗ FAILED! Claude not installed" -ForegroundColor Red
        
        if ($result.LogContent.ClaudeErrors) {
            Write-Host "`nClaude errors:" -ForegroundColor Yellow
            $result.LogContent.ClaudeErrors | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        if ($result.LogContent.Summary) {
            Write-Host "`nInstallation summary:" -ForegroundColor Yellow
            $result.LogContent.Summary | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}