# Test complete installation on fresh VM - Version 2
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FRESH INSTALLATION TEST V2" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $RemoteComputer (Fresh VM)" -ForegroundColor Yellow
Write-Host "Branch: enhanced-logging-remote-testing" -ForegroundColor Yellow
Write-Host "Goal: 100% automated installation" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to remote machine successfully" -ForegroundColor Green
    
    # Verify it's a fresh machine
    Write-Host "`nVerifying fresh VM state..." -ForegroundColor Yellow
    $preCheck = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        }
        
        $found = 0
        foreach ($app in $apps.GetEnumerator()) {
            if ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    if (Test-Path $path) { $found++; break }
                }
            } else {
                if (Test-Path $app.Value) { $found++ }
            }
        }
        
        return $found
    }
    
    Write-Host "Pre-installed apps found: $preCheck" -ForegroundColor $(if ($preCheck -eq 0) { "Green" } else { "Yellow" })
    
    # Download and save the web launcher locally on the remote machine
    Write-Host "`nDownloading and executing web launcher..." -ForegroundColor Yellow
    $installResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Set execution policy
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Download the web launcher
            $webLauncherUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing/SetupLab-WebLauncher-NoCache.ps1"
            $localPath = "C:\temp\SetupLab-WebLauncher.ps1"
            
            # Create temp directory if it doesn't exist
            if (-not (Test-Path "C:\temp")) {
                New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
            }
            
            Write-Host "Downloading web launcher to: $localPath"
            Invoke-WebRequest -Uri $webLauncherUrl -OutFile $localPath -UseBasicParsing
            
            # Execute the script with parameters
            Write-Host "Executing web launcher script..."
            & $localPath -BaseUrl "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing" -SkipValidation
            
            # Clean up
            Remove-Item $localPath -Force -ErrorAction SilentlyContinue
            
            return $true
        }
        catch {
            Write-Error "Installation failed: $_"
            return $false
        }
    }
    
    if ($installResult) {
        Write-Host "`nWeb launcher execution completed" -ForegroundColor Green
    } else {
        Write-Host "`nWeb launcher execution failed" -ForegroundColor Red
    }
    
    # Wait a bit for everything to settle
    Write-Host "`nWaiting for installations to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Final verification
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "FINAL VERIFICATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $finalResults = Invoke-Command -Session $session -ScriptBlock {
        $checks = @{
            "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "GitHub Desktop" = @("$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe", "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe")
            "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
            "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "Visual C++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp Terminal" = @("$env:LOCALAPPDATA\Programs\Warp\Warp.exe", "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe")
            "Windows Terminal" = $null  # Special check
            "Claude CLI" = @("$env:APPDATA\npm\claude.cmd", "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
        }
        
        $results = @()
        $installed = 0
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "Windows Terminal") {
                # Check via multiple methods
                $wtInApps = Test-Path "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*"
                $wtExe = Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
                $found = $wtInApps -or $wtExe
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
            elseif ($app.Value) {
                $found = Test-Path $app.Value
            }
            
            if ($found) { $installed++ }
            
            $results += [PSCustomObject]@{
                Name = $app.Key
                Installed = $found
            }
        }
        
        @{
            Results = $results | Sort-Object Name
            Installed = $installed
            Total = $checks.Count
        }
    }
    
    # Display results
    foreach ($app in $finalResults.Results) {
        $status = if ($app.Installed) { "INSTALLED" } else { "MISSING" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($finalResults.Installed / $finalResults.Total) * 100, 1)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RESULT: $($finalResults.Installed)/$($finalResults.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n[DONE] SUCCESS! 100% AUTOMATED INSTALLATION ACHIEVED!" -ForegroundColor Green
        Write-Host "All 16 applications installed without any manual intervention!" -ForegroundColor Green
    }
    else {
        Write-Host "`n[ERROR] Installation incomplete. Missing apps:" -ForegroundColor Red
        $missing = $finalResults.Results | Where-Object { -not $_.Installed }
        $missing | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Red }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}