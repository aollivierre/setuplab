# TEST WITH DEBUG OUTPUT
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING WITH DEBUG OUTPUT ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. Clearing Claude and running SetupLab..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        # Clear Claude first
        if (Test-Path "$env:APPDATA\npm\claude.cmd") {
            Write-Host "Removing existing Claude installation..." -ForegroundColor Yellow
            cmd /c "npm uninstall -g @anthropic-ai/claude-code 2>&1" | Out-Null
        }
        
        # Create log file
        $logFile = "C:\code\debug-test.log"
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        Start-Transcript -Path $logFile -Force
        
        Write-Host "`nRunning SetupLab for Claude only..." -ForegroundColor Yellow
        
        try {
            # Run just Claude installation
            $scriptBlock = {
                param($Software)
                iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
            }
            
            & $scriptBlock -Software @("Claude Code (CLI)")
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
    }
    
    # Wait briefly
    Write-Host "`n2. Waiting 30 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    Write-Host "`n3. Getting debug output..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        $output = @{
            ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
        }
        
        # Get the relevant log entries
        if (Test-Path "C:\code\debug-test.log") {
            $logContent = Get-Content "C:\code\debug-test.log"
            
            # Find Claude-related entries with context
            $claudeStart = $logContent | Select-String "Installing: Claude Code" -Context 0,20
            $customDebug = $logContent | Select-String "CUSTOM Install Path Resolution:" -Context 0,15
            $errorLines = $logContent | Select-String "Cannot bind|empty string|Passing CustomInstallScript" -Context 2,2
            
            $output.ClaudeContext = $claudeStart
            $output.CustomDebug = $customDebug
            $output.Errors = $errorLines
        }
        
        # Also check SetupLab logs
        $setupLabLogs = Get-ChildItem "C:\Users\ADMINI~1\AppData\Local\Temp\SetupLab_*\Logs\*.txt" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
            
        if ($setupLabLogs) {
            $setupLabContent = Get-Content $setupLabLogs.FullName | Select-String "Claude|CUSTOM|Passing CustomInstallScript" -Context 1,1
            $output.SetupLabLog = $setupLabContent
        }
        
        return $output
    }
    
    Write-Host "`nRESULTS:" -ForegroundColor Yellow
    Write-Host "Claude installed: $($result.ClaudeExists)" -ForegroundColor $(if($result.ClaudeExists){'Green'}else{'Red'})
    Write-Host "npm dir exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    
    if ($result.CustomDebug) {
        Write-Host "`nCUSTOM Debug Output:" -ForegroundColor Cyan
        $result.CustomDebug | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    if ($result.Errors) {
        Write-Host "`nError Context:" -ForegroundColor Red
        $result.Errors | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    if ($result.SetupLabLog) {
        Write-Host "`nSetupLab Log Entries:" -ForegroundColor Yellow
        $result.SetupLabLog | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}