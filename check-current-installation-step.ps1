# Check current installation step
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking current installation step..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $status = Invoke-Command -Session $session -ScriptBlock {
        # Get the main.log from temp
        $tempDir = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($tempDir) {
            $mainLog = Join-Path $tempDir.FullName "main.log"
            
            if (Test-Path $mainLog) {
                # Get all installation steps
                $content = Get-Content $mainLog
                $steps = $content | Where-Object { $_ -match "\[\d+/16\] Installing:" }
                
                @{
                    AllSteps = $steps
                    CurrentStep = $steps | Select-Object -Last 1
                    ClaudeStep = $steps | Where-Object { $_ -match "Claude" }
                }
            } else {
                # Try the Logs subdirectory
                $logsDir = Join-Path $tempDir.FullName "Logs"
                if (Test-Path $logsDir) {
                    $logFile = Get-ChildItem "$logsDir\*.txt" | Select-Object -First 1
                    if ($logFile) {
                        $content = Get-Content $logFile.FullName
                        $steps = $content | Where-Object { $_ -match "\[\d+/16\] Installing:" }
                        
                        @{
                            LogFile = $logFile.Name
                            AllSteps = $steps
                            CurrentStep = $steps | Select-Object -Last 1
                            ClaudeStep = $steps | Where-Object { $_ -match "Claude" }
                            LastLines = $content | Select-Object -Last 20
                        }
                    }
                }
            }
        }
    }
    
    if ($status) {
        Write-Host "`nInstallation Progress:" -ForegroundColor Cyan
        
        if ($status.AllSteps) {
            Write-Host "`nAll steps processed so far:" -ForegroundColor Yellow
            $status.AllSteps | ForEach-Object { 
                if ($_ -match "Claude") {
                    Write-Host $_ -ForegroundColor Cyan
                } else {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
            
            Write-Host "`nCurrent/Last step: $($status.CurrentStep)" -ForegroundColor Green
            
            if ($status.ClaudeStep) {
                Write-Host "`nClaude step found:" -ForegroundColor Cyan
                Write-Host $status.ClaudeStep -ForegroundColor Yellow
            }
        }
        
        if ($status.LastLines) {
            Write-Host "`nLast 20 log lines:" -ForegroundColor Yellow
            $status.LastLines | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
    
    # Final Claude check
    Write-Host "`nFinal Claude Check:" -ForegroundColor Cyan
    $claudeCheck = Invoke-Command -Session $session -ScriptBlock {
        @{
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
        }
    }
    
    Write-Host "npm directory: $(if($claudeCheck.NpmDirExists){'EXISTS'}else{'MISSING'})" -ForegroundColor $(if($claudeCheck.NpmDirExists){'Green'}else{'Red'})
    Write-Host "claude.cmd: $(if($claudeCheck.ClaudeExists){'INSTALLED'}else{'NOT FOUND'})" -ForegroundColor $(if($claudeCheck.ClaudeExists){'Green'}else{'Red'})
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}