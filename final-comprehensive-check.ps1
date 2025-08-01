# Final comprehensive check
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== FINAL COMPREHENSIVE CHECK ===" -ForegroundColor Magenta
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        $data = @{}
        
        # 1. Check processes
        $installers = Get-Process | Where-Object { $_.Name -match "msiexec|setup|install" }
        $data.InstallersRunning = $installers.Count
        $data.InstallerNames = ($installers | Select-Object -ExpandProperty Name -Unique) -join ", "
        
        # 2. Check SetupLab completion
        $summaryFiles = Get-ChildItem "C:\ProgramData\SetupLab\Logs\SetupSummary_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($summaryFiles) {
            $data.SummaryExists = $true
            $summaryContent = Get-Content $summaryFiles.FullName -Raw
            if ($summaryContent -match "Completed: (\d+)") { $data.Completed = $matches[1] }
            if ($summaryContent -match "Failed: (\d+)") { $data.Failed = $matches[1] }
            if ($summaryContent -match "Skipped: (\d+)") { $data.Skipped = $matches[1] }
            
            # Extract Claude info
            $data.ClaudeInSummary = $summaryContent -match "Claude"
            if ($data.ClaudeInSummary) {
                $data.ClaudeStatus = if ($summaryContent -match "Claude.*Success") { "Success" } 
                                    elseif ($summaryContent -match "Claude.*Failed") { "Failed" }
                                    else { "Unknown" }
            }
        }
        
        # 3. Check Claude specifically
        $data.NpmDirExists = Test-Path "$env:APPDATA\npm"
        $data.ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
        
        if ($data.ClaudeExists) {
            $data.ClaudeVersion = cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        
        # 4. Get latest log entries about Claude
        $logDir = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logDir) {
            $latestLog = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLog) {
                $claudeLines = Get-Content $latestLog.FullName | Where-Object { $_ -match "Claude" } | Select-Object -Last 10
                $data.ClaudeLogEntries = $claudeLines -join "`n"
            }
        }
        
        return $data
    }
    
    # Display results
    Write-Host "`n1. Installation Status:" -ForegroundColor Yellow
    Write-Host "   Active installers: $($result.InstallersRunning)" -ForegroundColor Gray
    if ($result.InstallersRunning -gt 0) {
        Write-Host "   Running: $($result.InstallerNames)" -ForegroundColor Gray
    }
    
    if ($result.SummaryExists) {
        Write-Host "`n2. SetupLab Summary:" -ForegroundColor Yellow
        Write-Host "   Completed: $($result.Completed)" -ForegroundColor Green
        Write-Host "   Failed: $($result.Failed)" -ForegroundColor Red
        Write-Host "   Skipped: $($result.Skipped)" -ForegroundColor Gray
    }
    
    Write-Host "`n3. Claude Code Status:" -ForegroundColor Yellow
    Write-Host "   npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "   Claude installed: $($result.ClaudeExists)" -ForegroundColor $(if($result.ClaudeExists){'Green'}else{'Red'})
    
    if ($result.ClaudeExists) {
        Write-Host "   Claude version: $($result.ClaudeVersion)" -ForegroundColor Green
    }
    
    if ($result.ClaudeLogEntries) {
        Write-Host "`n4. Claude-related log entries:" -ForegroundColor Yellow
        Write-Host $result.ClaudeLogEntries -ForegroundColor Gray
    }
    
    # Final verdict
    Write-Host "`n=== VERDICT ===" -ForegroundColor Cyan
    if ($result.ClaudeExists -and $result.ClaudeVersion -match "Claude Code") {
        Write-Host "✅ SUCCESS! Claude Code is installed and working!" -ForegroundColor Green
        Write-Host "The npm directory creation fix worked!" -ForegroundColor Green
    } elseif ($result.InstallersRunning -gt 0) {
        Write-Host "⏳ Installation still in progress..." -ForegroundColor Yellow
        Write-Host "Please wait for completion" -ForegroundColor Yellow
    } elseif (-not $result.NpmDirExists) {
        Write-Host "❌ The npm directory was not created" -ForegroundColor Red
        Write-Host "Claude installation likely failed" -ForegroundColor Red
    } else {
        Write-Host "Status unclear - check logs for details" -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}