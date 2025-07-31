# Complete test on fresh VM - using web launcher from our branch
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n##############################################################" -ForegroundColor Cyan
Write-Host "#                 FRESH VM COMPLETE TEST                     #" -ForegroundColor Cyan
Write-Host "##############################################################" -ForegroundColor Cyan
Write-Host "# VM: $RemoteComputer (Fresh from checkpoint)" -ForegroundColor Yellow
Write-Host "# Branch: enhanced-logging-remote-testing" -ForegroundColor Yellow
Write-Host "# Expected: 100% automated installation of all 16 apps" -ForegroundColor Yellow
Write-Host "##############################################################`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "[OK] Connected to fresh VM" -ForegroundColor Green
    
    # Verify it's truly fresh
    Write-Host "`n[STEP 1] Verifying VM is fresh..." -ForegroundColor Yellow
    $preCheck = Invoke-Command -Session $session -ScriptBlock {
        $appsInstalled = 0
        @("C:\Program Files\Git\bin\git.exe",
          "C:\Program Files\nodejs\node.exe",
          "C:\Program Files\Microsoft VS Code\Code.exe",
          "C:\Program Files\7-Zip\7z.exe") | ForEach-Object {
            if (Test-Path $_) { $appsInstalled++ }
        }
        return $appsInstalled
    }
    
    if ($preCheck -eq 0) {
        Write-Host "[OK] VM is fresh - no apps pre-installed" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Found $preCheck pre-installed apps" -ForegroundColor Yellow
    }
    
    # Run web launcher
    Write-Host "`n[STEP 2] Running SetupLab Web Launcher..." -ForegroundColor Yellow
    Write-Host "This will download and execute everything from our branch with all fixes" -ForegroundColor Gray
    
    $startTime = Get-Date
    
    $installJob = Invoke-Command -Session $session -AsJob -ScriptBlock {
        try {
            # Set execution policy
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Create temp directory
            if (-not (Test-Path "C:\temp")) {
                New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
            }
            
            # Download and run web launcher from our branch
            $webLauncherUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing/SetupLab-WebLauncher-NoCache.ps1"
            Write-Host "Downloading web launcher from: $webLauncherUrl"
            
            # Download to file first to avoid script block issues
            $localLauncher = "C:\temp\SetupLab-WebLauncher.ps1"
            Invoke-WebRequest -Uri $webLauncherUrl -OutFile $localLauncher -UseBasicParsing
            
            # Execute the launcher with our branch
            Write-Host "Executing launcher..."
            & $localLauncher -BaseUrl "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing" -SkipValidation:$false
            
            return $true
        }
        catch {
            Write-Error "Installation failed: $_"
            return $false
        }
    }
    
    Write-Host "[OK] Installation job started (ID: $($installJob.Id))" -ForegroundColor Green
    Write-Host "Monitoring progress..." -ForegroundColor Yellow
    
    # Monitor job
    $lastOutputCount = 0
    while ($installJob.State -eq 'Running') {
        $elapsed = (Get-Date) - $startTime
        $output = Receive-Job -Job $installJob -Keep
        $newOutput = $output | Select-Object -Skip $lastOutputCount
        
        if ($newOutput) {
            $newOutput | ForEach-Object { Write-Host $_ }
            $lastOutputCount = $output.Count
        } else {
            Write-Host "`rElapsed: $($elapsed.ToString('mm\:ss'))..." -NoNewline
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Get final output
    Write-Host ""
    $finalOutput = Receive-Job -Job $installJob
    $newOutput = $finalOutput | Select-Object -Skip $lastOutputCount
    if ($newOutput) {
        $newOutput | ForEach-Object { Write-Host $_ }
    }
    
    Write-Host "`n[INFO] Job completed with state: $($installJob.State)" -ForegroundColor $(if ($installJob.State -eq 'Completed') { 'Green' } else { 'Red' })
    Remove-Job -Job $installJob
    
    $duration = (Get-Date) - $startTime
    Write-Host "[INFO] Total installation time: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    
    # Wait for everything to settle
    Write-Host "`n[STEP 3] Waiting for installations to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Final verification
    Write-Host "`n[STEP 4] Final Verification..." -ForegroundColor Yellow
    
    $finalResults = Invoke-Command -Session $session -ScriptBlock {
        $checks = @{
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
            "15. Windows Terminal" = $null  # Special check
            "16. Claude CLI" = @("$env:APPDATA\npm\claude.cmd", "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
        }
        
        $results = @()
        $installed = 0
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "15. Windows Terminal") {
                # Multiple methods for Windows Terminal
                $found = (Test-Path "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*") -or
                        (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe") -or
                        ($null -ne (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue))
            }
            elseif ($app.Value -match "^HKLM:") {
                $found = Test-Path $app.Value
            }
            elseif ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
                    if (Test-Path $expandedPath) {
                        $found = $true
                        break
                    }
                }
            }
            else {
                $found = Test-Path $app.Value
            }
            
            if ($found) { $installed++ }
            $results += [PSCustomObject]@{
                Name = $app.Key
                Installed = $found
            }
        }
        
        # Get Node.js version
        $nodeVersion = $null
        if (Test-Path "C:\Program Files\nodejs\node.exe") {
            $nodeVersion = & "C:\Program Files\nodejs\node.exe" --version 2>$null
        }
        
        @{
            Results = $results | Sort-Object Name
            Installed = $installed
            Total = $checks.Count
            NodeVersion = $nodeVersion
        }
    }
    
    # Display results
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "#                    INSTALLATION RESULTS                    #" -ForegroundColor Cyan
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    # Progress bar
    Write-Host -NoNewline "`nProgress: ["
    for ($i = 1; $i -le 16; $i++) {
        if ($i -le $finalResults.Installed) {
            Write-Host -NoNewline "#" -ForegroundColor Green
        } else {
            Write-Host -NoNewline "-" -ForegroundColor Red
        }
    }
    Write-Host "] $($finalResults.Installed)/16`n"
    
    foreach ($app in $finalResults.Results) {
        $icon = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0} {1}" -f $icon, $app.Name) -ForegroundColor $color
    }
    
    if ($finalResults.NodeVersion) {
        Write-Host "`nNode.js version: $($finalResults.NodeVersion)" -ForegroundColor Cyan
    }
    
    $percentage = [math]::Round(($finalResults.Installed / $finalResults.Total) * 100, 1)
    
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "# FINAL SCORE: $($finalResults.Installed)/$($finalResults.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** PERFECT! 100% SUCCESS ON FRESH VM! ***" -ForegroundColor Green
        Write-Host "All 16 applications installed automatically!" -ForegroundColor Green
        Write-Host "The SetupLab installer is production-ready!" -ForegroundColor Green
        Write-Host "`nKey achievements:" -ForegroundColor Yellow
        Write-Host "  - No manual intervention required" -ForegroundColor Gray
        Write-Host "  - All apps installed silently" -ForegroundColor Gray
        Write-Host "  - Node.js MSI errors handled gracefully" -ForegroundColor Gray
        Write-Host "  - Claude CLI installed via npm" -ForegroundColor Gray
        Write-Host "  - Total time: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    }
    elseif ($percentage -ge 90) {
        Write-Host "`nExcellent result! Missing only:" -ForegroundColor Yellow
        $finalResults.Results | Where-Object { -not $_.Installed } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`nInstallation incomplete. Missing:" -ForegroundColor Red
        $finalResults.Results | Where-Object { -not $_.Installed } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}