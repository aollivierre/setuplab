# Get current installation logs
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Getting installation logs..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        $result = @{}
        
        # Check SetupLab logs
        $logDir = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logDir) {
            $latest = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latest) {
                $content = Get-Content $latest.FullName
                $result.TotalLines = $content.Count
                $result.ClaudeLines = $content | Where-Object { $_ -match "Claude" }
                $result.LastLines = $content | Select-Object -Last 30
                $result.Summary = $content | Where-Object { $_ -match "Installation Summary:|Completed:|Failed:|Skipped:" }
            }
        }
        
        # Check summary files
        $summaryFiles = Get-ChildItem "$env:TEMP\SetupLab_*\Logs\SetupSummary_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($summaryFiles) {
            $result.SummaryContent = Get-Content $summaryFiles.FullName -Raw
        }
        
        # Quick Claude check
        $result.ClaudeInstalled = Test-Path "$env:APPDATA\npm\claude.cmd"
        $result.NpmDirExists = Test-Path "$env:APPDATA\npm"
        
        return $result
    }
    
    Write-Host "`nQuick Status:" -ForegroundColor Cyan
    Write-Host "npm directory exists: $($logs.NpmDirExists)" -ForegroundColor $(if($logs.NpmDirExists){'Green'}else{'Red'})
    Write-Host "Claude installed: $($logs.ClaudeInstalled)" -ForegroundColor $(if($logs.ClaudeInstalled){'Green'}else{'Red'})
    
    if ($logs.ClaudeLines) {
        Write-Host "`nClaude-related log entries:" -ForegroundColor Yellow
        $logs.ClaudeLines | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    if ($logs.Summary) {
        Write-Host "`nInstallation Summary:" -ForegroundColor Yellow
        $logs.Summary | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    if ($logs.SummaryContent) {
        Write-Host "`nSummary File Content:" -ForegroundColor Cyan
        Write-Host $logs.SummaryContent -ForegroundColor Gray
    }
    
    if ($logs.LastLines -and -not $logs.ClaudeInstalled) {
        Write-Host "`nLast 30 log lines:" -ForegroundColor Yellow
        $logs.LastLines | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}