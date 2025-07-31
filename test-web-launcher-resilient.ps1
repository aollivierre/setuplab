# Resilient web launcher test - handles session loss
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n##############################################################" -ForegroundColor Cyan
Write-Host "#     RESILIENT WEB LAUNCHER TEST ON REMOTE MACHINE         #" -ForegroundColor Cyan
Write-Host "##############################################################" -ForegroundColor Cyan

function New-ResilientSession {
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
            return $session
        }
        catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "[RETRY] Waiting 5 seconds before retry $retryCount/$maxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
            else {
                throw $_
            }
        }
    }
}

try {
    # Initial connection
    Write-Host "[STEP 1] Connecting to remote machine..." -ForegroundColor Yellow
    $session = New-ResilientSession
    Write-Host "[OK] Connected successfully" -ForegroundColor Green
    
    # Clean up
    Write-Host "`n[STEP 2] Cleaning up previous attempts..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -ne "setuplab01" } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        
        Get-ChildItem "$env:TEMP\SetupLab_*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }
    Write-Host "[OK] Cleanup completed" -ForegroundColor Green
    
    # Start web launcher as a job
    Write-Host "`n[STEP 3] Starting web launcher..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    $installJob = Invoke-Command -Session $session -AsJob -ScriptBlock {
        try {
            # Run the web launcher
            iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
            return $true
        }
        catch {
            Write-Error $_
            return $false
        }
    }
    
    Write-Host "[OK] Installation job started (ID: $($installJob.Id))" -ForegroundColor Green
    Write-Host "Monitoring progress (session may be lost during PowerShell 7 install)..." -ForegroundColor Yellow
    
    # Monitor job
    $lastOutputCount = 0
    $sessionLost = $false
    
    while ($installJob.State -eq 'Running') {
        try {
            $output = Receive-Job -Job $installJob -Keep -ErrorAction Stop
            $newOutput = $output | Select-Object -Skip $lastOutputCount
            
            if ($newOutput) {
                $newOutput | ForEach-Object { Write-Host $_ }
                $lastOutputCount = $output.Count
            }
            else {
                $elapsed = (Get-Date) - $startTime
                Write-Host "`rElapsed: $($elapsed.ToString('mm\:ss'))..." -NoNewline
            }
        }
        catch {
            if (-not $sessionLost) {
                Write-Host "`n[WARN] Session lost (expected during PowerShell 7 install)" -ForegroundColor Yellow
                $sessionLost = $true
            }
        }
        
        Start-Sleep -Seconds 2
    }
    
    Write-Host "`n[INFO] Installation job completed" -ForegroundColor Green
    
    # Get final output
    try {
        $finalOutput = Receive-Job -Job $installJob -ErrorAction SilentlyContinue
        if ($finalOutput -and $finalOutput.Count -gt $lastOutputCount) {
            $finalOutput | Select-Object -Skip $lastOutputCount | ForEach-Object { Write-Host $_ }
        }
    }
    catch {
        # Ignore errors
    }
    
    Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
    
    # Close old session
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
    
    # Wait for services to stabilize
    Write-Host "`n[STEP 4] Waiting for services to stabilize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Reconnect for verification
    Write-Host "`n[STEP 5] Reconnecting for verification..." -ForegroundColor Yellow
    $session = New-ResilientSession
    Write-Host "[OK] Reconnected successfully" -ForegroundColor Green
    
    # Final verification
    Write-Host "`n[STEP 6] Final verification..." -ForegroundColor Yellow
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
            "01. 7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "02. Git" = "C:\Program Files\Git\bin\git.exe"
            "03. VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "04. Node.js" = "C:\Program Files\nodejs\node.exe"
            "05. GitHub Desktop" = @("$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe", "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe")
            "06. GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "07. PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "08. Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "09. Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "10. ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "11. Everything" = "C:\Program Files\Everything\Everything.exe"
            "12. FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "13. VC++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "14. Warp" = @("$env:LOCALAPPDATA\Programs\Warp\Warp.exe", "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe")
            "15. Windows Terminal" = $null
            "16. Claude CLI" = @("$env:APPDATA\npm\claude.cmd", "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
        }
        
        $installed = 0
        $details = @()
        
        foreach ($app in $apps.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "15. Windows Terminal") {
                $found = (Test-Path "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*") -or
                        (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe") -or
                        ($null -ne (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue))
            }
            elseif ($app.Value -match "^HKLM:") {
                $found = Test-Path $app.Value
            }
            elseif ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    if (Test-Path ([Environment]::ExpandEnvironmentVariables($path))) {
                        $found = $true
                        break
                    }
                }
            }
            else {
                $found = Test-Path $app.Value
            }
            
            if ($found) { $installed++ }
            $details += [PSCustomObject]@{
                Name = $app.Key
                Installed = $found
            }
        }
        
        @{
            Details = $details | Sort-Object Name
            Installed = $installed
            Total = $apps.Count
        }
    }
    
    # Display results
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "#                  WEB LAUNCHER RESULTS                      #" -ForegroundColor Cyan
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    foreach ($app in $results.Details) {
        $icon = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0} {1}" -f $icon, $app.Name) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
    $duration = (Get-Date) - $startTime
    
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "# RESULT: $($results.Installed)/$($results.Total) ($percentage%) - Time: $($duration.ToString('mm\:ss'))" -ForegroundColor $(if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 90) { "Yellow" } else { "Red" })
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** PERFECT! Web launcher achieved 100% success! ***" -ForegroundColor Green
        Write-Host "All fixes from main branch are working correctly!" -ForegroundColor Green
    }
    elseif ($percentage -ge 90) {
        Write-Host "`nExcellent result! Missing only:" -ForegroundColor Yellow
        $results.Details | Where-Object { -not $_.Installed } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
    }
    
    Remove-PSSession -Session $session -ErrorAction SilentlyContinue
}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}