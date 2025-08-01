# Check SetupLab logs on fresh system
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking SetupLab logs on fresh system..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        # Get latest SetupLab log
        $logDir = "C:\ProgramData\SetupLab\Logs"
        $result = @{
            LogDirExists = Test-Path $logDir
            Logs = @()
        }
        
        if ($result.LogDirExists) {
            $logFiles = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
            foreach ($log in $logFiles) {
                $content = Get-Content $log.FullName -Raw
                
                # Extract key information
                $claudeLines = $content -split "`n" | Where-Object { $_ -match "Claude|install-claude-cli" }
                $summarySection = $content -split "`n" | Where-Object { $_ -match "Installation Summary:|Completed:|Failed:" }
                
                $result.Logs += @{
                    FileName = $log.Name
                    LastWriteTime = $log.LastWriteTime
                    ClaudeRelated = $claudeLines -join "`n"
                    Summary = $summarySection -join "`n"
                }
            }
        }
        
        # Also check temp folders
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($tempFolders) {
            $tempLog = Get-ChildItem "$($tempFolders.FullName)\Logs\*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($tempLog) {
                $tempContent = Get-Content $tempLog.FullName -Tail 50
                $result.TempLog = $tempContent -join "`n"
            }
        }
        
        return $result
    }
    
    if ($logs.LogDirExists -and $logs.Logs.Count -gt 0) {
        foreach ($log in $logs.Logs) {
            Write-Host "`n=== Log: $($log.FileName) ===" -ForegroundColor Cyan
            Write-Host "Last Modified: $($log.LastWriteTime)" -ForegroundColor Gray
            
            if ($log.ClaudeRelated) {
                Write-Host "`nClaude-related entries:" -ForegroundColor Yellow
                Write-Host $log.ClaudeRelated -ForegroundColor Gray
            }
            
            if ($log.Summary) {
                Write-Host "`nSummary:" -ForegroundColor Yellow
                Write-Host $log.Summary -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No SetupLab logs found yet" -ForegroundColor Yellow
    }
    
    if ($logs.TempLog) {
        Write-Host "`n=== Latest Temp Log (last 50 lines) ===" -ForegroundColor Cyan
        Write-Host $logs.TempLog -ForegroundColor Gray
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}