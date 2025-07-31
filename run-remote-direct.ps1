# Run SetupLab directly on remote machine without web launcher
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Running SetupLab directly on remote machine: $RemoteComputer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to remote machine successfully" -ForegroundColor Green
    
    # Copy all necessary files to remote machine
    Write-Host "`nCopying SetupLab files to remote machine..." -ForegroundColor Yellow
    
    $remotePath = "C:\SetupLab"
    
    # Create remote directory
    Invoke-Command -Session $session -ScriptBlock {
        param($path)
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    } -ArgumentList $remotePath
    
    # Copy all files
    $filesToCopy = @(
        "main.ps1",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "software-config.json",
        "Download-Sysinternals.ps1",
        "Configure-WindowsTerminal.ps1",
        "install-claude-cli.ps1",
        "Set-DNSServers.ps1",
        "Rename-Computer.ps1",
        "Join-Domain.ps1"
    )
    
    foreach ($file in $filesToCopy) {
        $sourcePath = Join-Path $PSScriptRoot $file
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $remotePath -ToSession $session -Force
            Write-Host "  Copied: $file" -ForegroundColor Gray
        }
    }
    
    # Copy subdirectories
    $subDirs = @("DarkTheme", "Terminal")
    foreach ($dir in $subDirs) {
        $sourcePath = Join-Path $PSScriptRoot $dir
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $remotePath -ToSession $session -Recurse -Force
            Write-Host "  Copied directory: $dir" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nStarting SetupLab installation..." -ForegroundColor Yellow
    Write-Host "This will run unattended without any prompts" -ForegroundColor Green
    
    # Run the installation as a job
    $job = Invoke-Command -Session $session -AsJob -ScriptBlock {
        param($setupPath)
        
        Set-Location $setupPath
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Run main.ps1 with skip validation flag
        & (Join-Path $setupPath "main.ps1") -SkipValidation
    } -ArgumentList $remotePath
    
    Write-Host "`nInstallation job started with ID: $($job.Id)" -ForegroundColor Green
    Write-Host "Monitoring progress..." -ForegroundColor Yellow
    
    # Monitor job
    $startTime = Get-Date
    $lastOutputCount = 0
    
    while ($job.State -eq 'Running') {
        $elapsed = (Get-Date) - $startTime
        
        # Get job output
        $output = Receive-Job -Job $job -Keep
        $newOutput = $output | Select-Object -Skip $lastOutputCount
        
        if ($newOutput) {
            $newOutput | ForEach-Object { Write-Host $_ }
            $lastOutputCount = $output.Count
        }
        else {
            Write-Host "`rElapsed: $($elapsed.ToString('mm\:ss'))..." -NoNewline
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Get final output
    Write-Host ""
    $finalOutput = Receive-Job -Job $job
    $newOutput = $finalOutput | Select-Object -Skip $lastOutputCount
    if ($newOutput) {
        $newOutput | ForEach-Object { Write-Host $_ }
    }
    
    Write-Host "`nJob completed with state: $($job.State)" -ForegroundColor $(if ($job.State -eq 'Completed') { 'Green' } else { 'Red' })
    
    # Check for errors
    if ($job.State -eq 'Failed') {
        Write-Host "`nJob failed with error:" -ForegroundColor Red
        $job.ChildJobs | ForEach-Object {
            if ($_.Error) {
                $_.Error | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
        }
    }
    
    Remove-Job -Job $job
    
    # Check results
    Write-Host "`nChecking installation results..." -ForegroundColor Yellow
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $installed = @()
        $notInstalled = @()
        
        $software = @{
            "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
        }
        
        foreach ($app in $software.GetEnumerator()) {
            $found = $false
            if ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    if (Test-Path $path) {
                        $installed += $app.Key
                        $found = $true
                        break
                    }
                }
            }
            else {
                if (Test-Path $app.Value) {
                    $installed += $app.Key
                    $found = $true
                }
            }
            
            if (-not $found) {
                $notInstalled += $app.Key
            }
        }
        
        # Check logs
        $logInfo = $null
        $logPath = "C:\SetupLab\Logs"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem -Path $logPath -Filter "SetupLab_*.log" | 
                         Sort-Object LastWriteTime -Descending | 
                         Select-Object -First 1
            if ($latestLog) {
                $errors = Get-Content $latestLog.FullName | Select-String -Pattern "\[Error\]" | Select-Object -Last 10
                $logInfo = @{
                    FileName = $latestLog.Name
                    Errors = $errors
                    LastLines = Get-Content $latestLog.FullName -Tail 30
                }
            }
        }
        
        @{
            Installed = $installed
            NotInstalled = $notInstalled
            LogInfo = $logInfo
        }
    }
    
    Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
    Write-Host "Installed ($($results.Installed.Count)): $($results.Installed -join ', ')" -ForegroundColor Green
    if ($results.NotInstalled.Count -gt 0) {
        Write-Host "Not Installed ($($results.NotInstalled.Count)): $($results.NotInstalled -join ', ')" -ForegroundColor Yellow
    }
    
    if ($results.LogInfo) {
        Write-Host "`nLog file: $($results.LogInfo.FileName)" -ForegroundColor Cyan
        
        if ($results.LogInfo.Errors) {
            Write-Host "`nRecent errors:" -ForegroundColor Red
            $results.LogInfo.Errors | ForEach-Object { Write-Host $_ }
        }
        
        Write-Host "`nLast log entries:" -ForegroundColor Yellow
        $results.LogInfo.LastLines | ForEach-Object { Write-Host $_ }
    }
    
    Remove-PSSession -Session $session
    Write-Host "`nRemote execution completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}