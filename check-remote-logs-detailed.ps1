# Check remote logs in c:\code\logs
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking logs on $RemoteComputer in C:\code\logs..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        # Check C:\code\logs
        if (Test-Path "C:\code\logs") {
            $logFiles = Get-ChildItem "C:\code\logs\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            
            foreach ($logFile in $logFiles) {
                $results[$logFile.Name] = @{
                    Path = $logFile.FullName
                    LastWriteTime = $logFile.LastWriteTime
                    Size = $logFile.Length
                    LastLines = Get-Content $logFile.FullName -Tail 30 -ErrorAction SilentlyContinue
                }
            }
        }
        
        # Also check C:\ProgramData\SetupLab\Logs for the latest
        if (Test-Path "C:\ProgramData\SetupLab\Logs") {
            $setupLabLogs = Get-ChildItem "C:\ProgramData\SetupLab\Logs\*.txt" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            
            if ($setupLabLogs) {
                # Look for Claude CLI specific errors
                $content = Get-Content $setupLabLogs.FullName -Raw
                $claudeErrors = $content | Select-String -Pattern "Claude CLI|install-claude-cli" -Context 2,2 -AllMatches
                
                $results.SetupLabClaudeErrors = @{
                    Path = $setupLabLogs.FullName
                    Errors = $claudeErrors.Matches | ForEach-Object { $_.Line }
                }
            }
        }
        
        return $results
    }
    
    # Display C:\code\logs files
    if ($logs.Count -gt 0) {
        foreach ($logName in $logs.Keys) {
            if ($logName -ne 'SetupLabClaudeErrors') {
                $log = $logs[$logName]
                Write-Host "`nLog: $logName" -ForegroundColor Cyan
                Write-Host "Path: $($log.Path)"
                Write-Host "Last Modified: $($log.LastWriteTime)"
                Write-Host "Size: $($log.Size) bytes"
                
                if ($log.LastLines) {
                    Write-Host "`nLast 30 lines:" -ForegroundColor Yellow
                    $log.LastLines | ForEach-Object { Write-Host $_ }
                }
            }
        }
    } else {
        Write-Host "No logs found in C:\code\logs" -ForegroundColor Yellow
    }
    
    # Display Claude-specific errors
    if ($logs.SetupLabClaudeErrors -and $logs.SetupLabClaudeErrors.Errors) {
        Write-Host "`n`nClaude CLI Errors from SetupLab:" -ForegroundColor Red
        Write-Host "From: $($logs.SetupLabClaudeErrors.Path)" -ForegroundColor Gray
        $logs.SetupLabClaudeErrors.Errors | ForEach-Object { Write-Host $_ }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}