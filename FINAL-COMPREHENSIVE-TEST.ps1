# FINAL COMPREHENSIVE TEST - NO MORE SCRIPTS AFTER THIS
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== FINAL COMPREHENSIVE TEST ON FRESH VM ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

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
    
    Write-Host "`n1. RUNNING WEB LAUNCHER..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create log file to capture everything
        $logFile = "C:\code\full-installation-log.txt"
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        
        Start-Transcript -Path $logFile -Force
        
        Write-Host "Starting SetupLab installation..." -ForegroundColor Green
        
        # Run the web launcher
        try {
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        } catch {
            Write-Host "ERROR IN WEB LAUNCHER: $_" -ForegroundColor Red
        }
        
        Stop-Transcript
        
        # Return key info
        @{
            LogCreated = Test-Path $logFile
            ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
        }
    }
    
    # Wait for completion
    Write-Host "`n2. Waiting for installation to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120  # 2 minutes should be enough
    
    Write-Host "`n3. CHECKING RESULTS..." -ForegroundColor Cyan
    
    $finalResult = Invoke-Command -Session $session -ScriptBlock {
        $result = @{
            # Claude status
            ClaudeCmd = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDir = Test-Path "$env:APPDATA\npm"
            
            # Get the error from log
            LogContent = if (Test-Path "C:\code\full-installation-log.txt") {
                Get-Content "C:\code\full-installation-log.txt" | Where-Object { $_ -match "Claude|Error|Failed|empty string" } | Select-Object -Last 30
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
                $content = Get-Content $files.FullName | Where-Object { $_ -match "Claude" }
                if ($content) {
                    $result.SetupLabLogs += $content
                }
            }
        }
        
        return $result
    }
    
    Write-Host "`n=== RESULTS ===" -ForegroundColor Red
    Write-Host "npm directory exists: $($finalResult.NpmDir)" -ForegroundColor $(if($finalResult.NpmDir){'Green'}else{'Red'})
    Write-Host "Claude installed: $($finalResult.ClaudeCmd)" -ForegroundColor $(if($finalResult.ClaudeCmd){'Green'}else{'Red'})
    
    if (-not $finalResult.ClaudeCmd) {
        Write-Host "`nCLAUDE INSTALLATION FAILED!" -ForegroundColor Red
        
        if ($finalResult.LogContent) {
            Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
            $finalResult.LogContent | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        if ($finalResult.SetupLabLogs) {
            Write-Host "`nSetupLab Claude entries:" -ForegroundColor Yellow
            $finalResult.SetupLabLogs | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
        
        Write-Host "`nTHE ISSUE:" -ForegroundColor Red
        Write-Host "Claude fails when run through SetupLab but works in isolation" -ForegroundColor Red
        Write-Host "This suggests the issue is in how SetupLabCore.psm1 invokes CUSTOM scripts" -ForegroundColor Red
    } else {
        Write-Host "`nSUCCESS! Claude installed correctly!" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}