# Check Claude status after installation
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nChecking Claude Code installation status..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Check various locations
        $npmDir = "$env:APPDATA\npm"
        $claudeCmd = "$npmDir\claude.cmd"
        
        $status = @{
            NpmDirExists = Test-Path $npmDir
            NpmDirContents = if (Test-Path $npmDir) { Get-ChildItem $npmDir | Select-Object Name } else { @() }
            ClaudeCmdExists = Test-Path $claudeCmd
            ClaudeVersion = if (Test-Path $claudeCmd) {
                cmd /c "`"$claudeCmd`" --version 2>&1"
            } else {
                "Not found"
            }
        }
        
        # Check if installation is still running
        $setupLabProcesses = Get-Process | Where-Object { $_.Name -match "msiexec|setup|install" }
        $status.InstallersRunning = $setupLabProcesses.Count -gt 0
        
        # Get latest log
        $logDir = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logDir) {
            $latestLog = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLog) {
                $claudeLines = Get-Content $latestLog.FullName | Where-Object { $_ -match "Claude" } | Select-Object -Last 10
                $status.LatestClaudeLog = $claudeLines -join "`n"
            }
        }
        
        return $status
    }
    
    Write-Host "`nClaude Code Status:" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    
    if ($result.NpmDirContents.Count -gt 0) {
        Write-Host "npm directory contents:" -ForegroundColor Gray
        $result.NpmDirContents | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
    }
    
    Write-Host "claude.cmd exists: $($result.ClaudeCmdExists)" -ForegroundColor $(if($result.ClaudeCmdExists){'Green'}else{'Red'})
    Write-Host "Claude version: $($result.ClaudeVersion)" -ForegroundColor $(if($result.ClaudeVersion -match "Claude Code"){'Green'}else{'Yellow'})
    
    if ($result.InstallersRunning) {
        Write-Host "`nNote: Installation processes are still running" -ForegroundColor Yellow
    }
    
    if ($result.LatestClaudeLog) {
        Write-Host "`nLatest Claude-related log entries:" -ForegroundColor Cyan
        Write-Host $result.LatestClaudeLog -ForegroundColor Gray
    }
    
    if ($result.ClaudeCmdExists -and $result.ClaudeVersion -match "Claude Code") {
        Write-Host "`n✅ SUCCESS! Claude Code is installed and working!" -ForegroundColor Green
        Write-Host "Version: $($result.ClaudeVersion)" -ForegroundColor Green
    } elseif ($result.InstallersRunning) {
        Write-Host "`n⏳ Installation may still be in progress..." -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ Claude Code installation issue detected" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}