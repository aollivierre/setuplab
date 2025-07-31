# Analyze what went wrong with the remote installation
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Analyzing remote installation issues..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $analysis = Invoke-Command -Session $session -ScriptBlock {
        $results = @{
            ProcessRunning = $false
            Installers = @()
            RecentErrors = @()
            DiskSpace = $null
            TempFiles = @()
            EventLogs = @()
        }
        
        # Check if any installer processes are still running
        $installerProcesses = Get-Process -Name "msiexec", "setup*", "*installer*" -ErrorAction SilentlyContinue
        if ($installerProcesses) {
            $results.ProcessRunning = $true
            $results.Installers = $installerProcesses | Select-Object Name, Id, StartTime, CPU
        }
        
        # Check disk space
        $drive = Get-PSDrive C
        $results.DiskSpace = @{
            FreeGB = [math]::Round($drive.Free / 1GB, 2)
            UsedGB = [math]::Round($drive.Used / 1GB, 2)
            PercentFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 2)
        }
        
        # Check temp files
        $tempPath = $env:TEMP
        $results.TempFiles = Get-ChildItem -Path $tempPath -Filter "*installer*" -ErrorAction SilentlyContinue | 
                             Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
                             Select-Object Name, Length, LastWriteTime
        
        # Get recent application event logs
        try {
            $results.EventLogs = Get-EventLog -LogName Application -EntryType Error -Newest 20 -After (Get-Date).AddHours(-1) |
                                Where-Object { $_.Source -match "MsiInstaller|Windows Installer" } |
                                Select-Object TimeGenerated, Source, Message
        } catch {}
        
        # Check all log files
        $logPath = "C:\SetupLab\Logs"
        if (Test-Path $logPath) {
            $allLogs = Get-ChildItem -Path $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending
            $results.AllLogs = $allLogs | Select-Object Name, Length, LastWriteTime
            
            # Get content from all recent logs
            foreach ($log in ($allLogs | Select-Object -First 3)) {
                $content = Get-Content $log.FullName -Tail 50
                $results.RecentErrors += $content | Where-Object { $_ -match '\[Error\]|\[Warning\]' }
            }
        }
        
        # Check if PowerShell process is still running main.ps1
        $psProcesses = Get-Process powershell* -ErrorAction SilentlyContinue
        foreach ($ps in $psProcesses) {
            try {
                $commandLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($ps.Id)").CommandLine
                if ($commandLine -match "main\.ps1") {
                    $results.MainScriptRunning = $true
                    $results.MainScriptProcess = @{
                        Id = $ps.Id
                        StartTime = $ps.StartTime
                        CPU = $ps.CPU
                        CommandLine = $commandLine
                    }
                }
            } catch {}
        }
        
        return $results
    }
    
    # Display results
    Write-Host "`nDisk Space:" -ForegroundColor Yellow
    Write-Host "  Free: $($analysis.DiskSpace.FreeGB) GB ($($analysis.DiskSpace.PercentFree)%)" -ForegroundColor Gray
    
    if ($analysis.ProcessRunning) {
        Write-Host "`nActive Installer Processes:" -ForegroundColor Red
        $analysis.Installers | Format-Table -AutoSize
    }
    
    if ($analysis.MainScriptRunning) {
        Write-Host "`nMain script still running!" -ForegroundColor Red
        Write-Host "  Process ID: $($analysis.MainScriptProcess.Id)"
        Write-Host "  Start Time: $($analysis.MainScriptProcess.StartTime)"
        Write-Host "  CPU Time: $($analysis.MainScriptProcess.CPU)"
    }
    
    if ($analysis.AllLogs) {
        Write-Host "`nLog Files:" -ForegroundColor Yellow
        $analysis.AllLogs | Format-Table -AutoSize
    }
    
    if ($analysis.RecentErrors) {
        Write-Host "`nRecent Errors/Warnings:" -ForegroundColor Red
        $analysis.RecentErrors | Select-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
    }
    
    if ($analysis.EventLogs) {
        Write-Host "`nWindows Installer Event Logs:" -ForegroundColor Yellow
        $analysis.EventLogs | ForEach-Object {
            Write-Host "  $($_.TimeGenerated) - $($_.Source)" -ForegroundColor Gray
            Write-Host "    $($_.Message.Split("`n")[0])" -ForegroundColor DarkGray
        }
    }
    
    if ($analysis.TempFiles) {
        Write-Host "`nTemp Installer Files:" -ForegroundColor Yellow
        $analysis.TempFiles | Format-Table -AutoSize
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}