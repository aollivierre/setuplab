# FINAL TEST RESULT - Run this to check if Claude installed successfully
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FINAL CLAUDE INSTALLATION TEST RESULT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        @{
            # Check Claude
            ClaudeCmd = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDir = Test-Path "$env:APPDATA\npm"
            ClaudeVersion = if (Test-Path "$env:APPDATA\npm\claude.cmd") {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            } else { "Not installed" }
            
            # Check if installers are still running
            InstallersActive = (Get-Process | Where-Object { $_.Name -match "msiexec|setup|install" }).Count -gt 0
            
            # Get summary
            SummaryFile = Get-ChildItem "C:\ProgramData\SetupLab\Logs\SetupSummary_*.txt" -ErrorAction SilentlyContinue | 
                         Sort-Object LastWriteTime -Descending | 
                         Select-Object -First 1 | 
                         Get-Content -Raw
        }
    }
    
    Write-Host "`nRESULTS:" -ForegroundColor Yellow
    Write-Host "========" -ForegroundColor Yellow
    
    Write-Host "`nnpm directory exists: " -NoNewline
    if ($result.NpmDir) {
        Write-Host "YES [OK]" -ForegroundColor Green
    } else {
        Write-Host "NO [FAIL]" -ForegroundColor Red
    }
    
    Write-Host "Claude Code installed: " -NoNewline
    if ($result.ClaudeCmd) {
        Write-Host "YES [OK]" -ForegroundColor Green
        Write-Host "Version: $($result.ClaudeVersion)" -ForegroundColor Green
    } else {
        Write-Host "NO [FAIL]" -ForegroundColor Red
    }
    
    if ($result.InstallersActive) {
        Write-Host "`nNote: Installation processes are still active" -ForegroundColor Yellow
    }
    
    Write-Host "`nFINAL VERDICT:" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    
    if ($result.ClaudeCmd -and $result.ClaudeVersion -match "Claude Code") {
        Write-Host "[DONE] SUCCESS! Claude Code installed successfully on fresh system!" -ForegroundColor Green
        Write-Host "[DONE] The npm directory creation fix WORKED!" -ForegroundColor Green
        Write-Host "[DONE] Version: $($result.ClaudeVersion)" -ForegroundColor Green
    } elseif ($result.InstallersActive) {
        Write-Host "[WAIT] Installation is still in progress" -ForegroundColor Yellow
        Write-Host "[WAIT] Please run this script again in a few minutes" -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Claude Code was NOT installed" -ForegroundColor Red
        Write-Host "[ERROR] The npm directory was not created: $($result.NpmDir)" -ForegroundColor Red
        
        if ($result.SummaryFile -match "Claude.*Failed") {
            Write-Host "`nSetupLab reported Claude installation failed" -ForegroundColor Red
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nMake sure the remote system is accessible" -ForegroundColor Yellow
}