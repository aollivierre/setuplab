# Check detailed SetupLab logs on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking detailed logs on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        # Get the latest SetupLab log
        $logDir = "C:\ProgramData\SetupLab\Logs"
        $latestLog = if (Test-Path $logDir) {
            $logFile = Get-ChildItem "$logDir\*.txt" | Sort LastWriteTime -Desc | Select -First 1
            @{
                FileName = $logFile.Name
                LastWriteTime = $logFile.LastWriteTime
                Content = Get-Content $logFile.FullName -Raw
            }
        } else {
            $null
        }
        
        # Also check temp directories for custom script logs
        $tempLogs = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort LastWriteTime -Desc | Select -First 1
        $customScriptLog = if ($tempLogs) {
            $logFile = Join-Path $tempLogs.FullName "Logs\SetupLab_*.txt"
            if (Test-Path $logFile) {
                $file = Get-Item $logFile | Select -First 1
                Get-Content $file -Raw | Select-String "CUSTOM|Claude|PATH" -Context 5,5
            }
        }
        
        @{
            MainLog = $latestLog
            CustomScriptMatches = $customScriptLog
        }
    }
    
    if ($logs.MainLog) {
        Write-Host "`nLatest SetupLab log: $($logs.MainLog.FileName)" -ForegroundColor Cyan
        Write-Host "Last modified: $($logs.MainLog.LastWriteTime)" -ForegroundColor Gray
        
        # Save to local file
        $logs.MainLog.Content | Out-File -FilePath "C:\code\setuplab\remote-setuplab-log-detailed.txt" -Encoding UTF8
        Write-Host "Full log saved to: C:\code\setuplab\remote-setuplab-log-detailed.txt" -ForegroundColor Green
        
        # Show Claude CLI relevant entries
        Write-Host "`nClaude CLI related entries:" -ForegroundColor Yellow
        $logs.MainLog.Content -split "`n" | Where-Object { $_ -match "Claude|CUSTOM|PATH|install-claude" } | Select -Last 30
    }
    
    if ($logs.CustomScriptMatches) {
        Write-Host "`nCustom script execution context:" -ForegroundColor Yellow
        $logs.CustomScriptMatches
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}