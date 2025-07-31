# Run SetupLab on remote machine with proper execution policy handling
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234",
    [switch]$TestOnly
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Running SetupLab on remote machine: $RemoteComputer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to remote machine successfully" -ForegroundColor Green
    
    # Run the installation
    Write-Host "`nStarting SetupLab installation..." -ForegroundColor Yellow
    
    $scriptBlock = {
        param($TestOnly)
        
        # Set execution policy for the process
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Download and execute the web launcher directly
        $webLauncherUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing/SetupLab-WebLauncher-NoCache.ps1"
        
        Write-Host "Downloading SetupLab Web Launcher..." -ForegroundColor Yellow
        $webLauncherContent = (Invoke-WebRequest -Uri $webLauncherUrl -UseBasicParsing).Content
        
        # Create script block from content
        $scriptBlock = [scriptblock]::Create($webLauncherContent)
        
        # Set parameters
        $params = @{
            BaseUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing"
        }
        
        if ($TestOnly) {
            $params['ListSoftware'] = $true
        }
        else {
            # For actual installation, skip validation since it's a fresh machine
            $params['SkipValidation'] = $true
        }
        
        # Execute the script block
        & $scriptBlock @params
    }
    
    if ($TestOnly) {
        Write-Host "`nRunning in test mode (listing software only)..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $TestOnly
    }
    else {
        Write-Host "`nRunning full installation..." -ForegroundColor Yellow
        Write-Host "This may take 10-15 minutes. The script will continue running on the remote machine." -ForegroundColor Yellow
        
        # Start as a job so we don't timeout
        $job = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $TestOnly -AsJob
        
        Write-Host "`nInstallation job started with ID: $($job.Id)" -ForegroundColor Green
        Write-Host "Monitoring progress..." -ForegroundColor Yellow
        
        # Monitor job progress
        $startTime = Get-Date
        while ($job.State -eq 'Running') {
            $elapsed = (Get-Date) - $startTime
            Write-Host "`rElapsed time: $($elapsed.ToString('mm\:ss'))..." -NoNewline
            Start-Sleep -Seconds 5
            
            # Check for any output
            $output = Receive-Job -Job $job -Keep
            if ($output) {
                Write-Host ""
                $output | ForEach-Object { Write-Host $_ }
            }
        }
        
        Write-Host ""
        Write-Host "`nJob completed with state: $($job.State)" -ForegroundColor $(if ($job.State -eq 'Completed') { 'Green' } else { 'Red' })
        
        # Get final output
        $finalOutput = Receive-Job -Job $job
        if ($finalOutput) {
            $finalOutput | ForEach-Object { Write-Host $_ }
        }
        
        # Clean up job
        Remove-Job -Job $job
        
        # Check installation results
        Write-Host "`nChecking installation results..." -ForegroundColor Yellow
        
        $results = Invoke-Command -Session $session -ScriptBlock {
            $software = @{
                "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
                "Git" = "C:\Program Files\Git\bin\git.exe"
                "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
                "Node.js" = "C:\Program Files\nodejs\node.exe"
                "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
                "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
                "Chrome" = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            }
            
            $installed = @()
            $notInstalled = @()
            
            foreach ($app in $software.GetEnumerator()) {
                if (Test-Path $app.Value) {
                    $installed += $app.Key
                }
                else {
                    # Check alternative locations
                    $altPaths = @()
                    if ($app.Key -eq "Chrome") {
                        $altPaths += "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
                    }
                    
                    $found = $false
                    foreach ($altPath in $altPaths) {
                        if (Test-Path $altPath) {
                            $installed += $app.Key
                            $found = $true
                            break
                        }
                    }
                    
                    if (-not $found) {
                        $notInstalled += $app.Key
                    }
                }
            }
            
            @{
                Installed = $installed
                NotInstalled = $notInstalled
                Total = $software.Count
            }
        }
        
        Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
        Write-Host "  Total checked: $($results.Total)" -ForegroundColor White
        Write-Host "  Installed: $($results.Installed.Count) - $($results.Installed -join ', ')" -ForegroundColor Green
        if ($results.NotInstalled.Count -gt 0) {
            Write-Host "  Not installed: $($results.NotInstalled.Count) - $($results.NotInstalled -join ', ')" -ForegroundColor Yellow
        }
        
        # Get log file content
        Write-Host "`nChecking for log files..." -ForegroundColor Yellow
        
        $logs = Invoke-Command -Session $session -ScriptBlock {
            $logPath = "C:\ProgramData\SetupLab\Logs"
            if (Test-Path $logPath) {
                $latestLog = Get-ChildItem -Path $logPath -Filter "*.log" | 
                             Sort-Object LastWriteTime -Descending | 
                             Select-Object -First 1
                if ($latestLog) {
                    @{
                        FileName = $latestLog.Name
                        LastLines = Get-Content $latestLog.FullName -Tail 50
                        Errors = Get-Content $latestLog.FullName | Select-String -Pattern "\[Error\]" | Select-Object -Last 10
                    }
                }
            }
        }
        
        if ($logs) {
            Write-Host "`nLatest log file: $($logs.FileName)" -ForegroundColor Cyan
            
            if ($logs.Errors) {
                Write-Host "`nRecent errors:" -ForegroundColor Red
                $logs.Errors | ForEach-Object { Write-Host $_ }
            }
            
            Write-Host "`nLast 20 log entries:" -ForegroundColor Yellow
            $logs.LastLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
        }
    }
    
    # Cleanup
    Remove-PSSession -Session $session
    Write-Host "`nRemote execution completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
}