# Check all SetupLab logs on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking all SetupLab logs on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        # Check main logs location
        $mainLogPath = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $mainLogPath) {
            $summaryFiles = Get-ChildItem "$mainLogPath\SetupSummary_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($summaryFiles) {
                $content = Get-Content $summaryFiles.FullName -Tail 50
                $results.MainLog = @{
                    Path = $summaryFiles.FullName
                    LastLines = $content -join "`n"
                }
            }
        }
        
        # Check temp folders
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($tempFolders) {
            $results.TempFolder = $tempFolders.FullName
        }
        
        # Check if Claude CLI install is in progress
        $claudeProcesses = Get-Process -Name "npm", "node" -ErrorAction SilentlyContinue
        $results.NpmRunning = $claudeProcesses.Count -gt 0
        
        return $results
    }
    
    if ($logs.MainLog) {
        Write-Host "`nFound main log at: $($logs.MainLog.Path)" -ForegroundColor Green
        Write-Host "`nLast 50 lines:" -ForegroundColor Cyan
        Write-Host $logs.MainLog.LastLines
    }
    
    if ($logs.TempFolder) {
        Write-Host "`nLatest temp folder: $($logs.TempFolder)" -ForegroundColor Yellow
    }
    
    if ($logs.NpmRunning) {
        Write-Host "`nNPM/Node processes are still running" -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}