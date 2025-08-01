# Monitor installation progress
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Monitoring SetupLab installation progress..." -ForegroundColor Cyan
Write-Host "This will check every 30 seconds until Claude is installed or installation completes`n" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $claudeInstalled = $false
    $attempt = 0
    $maxAttempts = 20  # 10 minutes max
    
    while (-not $claudeInstalled -and $attempt -lt $maxAttempts) {
        $attempt++
        Write-Host "Check $attempt/$maxAttempts..." -ForegroundColor Yellow
        
        $status = Invoke-Command -Session $session -ScriptBlock {
            # Get latest from temp log
            $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $lastStep = "Unknown"
            
            if ($tempFolders) {
                $mainLog = Join-Path $tempFolders.FullName "main.log"
                if (Test-Path $mainLog) {
                    $recentLines = Get-Content $mainLog -Tail 5 -ErrorAction SilentlyContinue
                    $lastStep = ($recentLines | Where-Object { $_ -match "\[\d+/16\]" } | Select-Object -Last 1) -replace ".*(\[\d+/16\].*)$", '$1'
                }
            }
            
            @{
                ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
                LastStep = $lastStep
                ActiveProcesses = (Get-Process | Where-Object { $_.Name -match "msiexec|setup|install" }).Count
            }
        }
        
        Write-Host "  Last step: $($status.LastStep)" -ForegroundColor Gray
        Write-Host "  Active installers: $($status.ActiveProcesses)" -ForegroundColor Gray
        Write-Host "  Claude installed: $($status.ClaudeExists)" -ForegroundColor $(if($status.ClaudeExists){'Green'}else{'Gray'})
        
        if ($status.ClaudeExists) {
            $claudeInstalled = $true
            
            # Get version
            $version = Invoke-Command -Session $session -ScriptBlock {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            }
            
            Write-Host "`n[DONE] SUCCESS! Claude Code has been installed!" -ForegroundColor Green
            Write-Host "Version: $version" -ForegroundColor Green
            Write-Host "`nThe fix worked! Claude Code installed successfully on the fresh system." -ForegroundColor Green
        }
        elseif ($status.ActiveProcesses -eq 0) {
            Write-Host "`n[WARNING] Installation appears to have completed but Claude was not found" -ForegroundColor Yellow
            break
        }
        else {
            Write-Host "  Waiting 30 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
        }
    }
    
    if (-not $claudeInstalled) {
        Write-Host "`n[ERROR] Claude was not installed after monitoring" -ForegroundColor Red
        
        # Get final log
        $finalLog = Invoke-Command -Session $session -ScriptBlock {
            $logDir = "C:\ProgramData\SetupLab\Logs"
            if (Test-Path $logDir) {
                $latest = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($latest) {
                    Get-Content $latest.FullName | Where-Object { $_ -match "Claude|Error|Failed" } | Select-Object -Last 20
                }
            }
        }
        
        if ($finalLog) {
            Write-Host "`nRelevant log entries:" -ForegroundColor Yellow
            $finalLog | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}