# Test running main.ps1 directly on fresh VM
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DIRECT MAIN.PS1 INSTALLATION TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $RemoteComputer (Fresh VM)" -ForegroundColor Yellow
Write-Host "Branch: enhanced-logging-remote-testing" -ForegroundColor Yellow
Write-Host "Goal: 100% automated installation" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to remote machine successfully" -ForegroundColor Green
    
    # First, copy all required files to the remote machine
    Write-Host "`nCopying setup files to remote machine..." -ForegroundColor Yellow
    
    # Create remote directory
    Invoke-Command -Session $session -ScriptBlock {
        if (Test-Path "C:\SetupLab") {
            Remove-Item "C:\SetupLab" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "C:\SetupLab" -Force | Out-Null
    }
    
    # Copy main files
    $filesToCopy = @(
        "main.ps1",
        "software-config.json",
        "settings.local.json"
    )
    
    foreach ($file in $filesToCopy) {
        $localPath = "C:\code\setuplab\$file"
        $remotePath = "C:\SetupLab\$file"
        Write-Host "  Copying $file..."
        Copy-Item -Path $localPath -Destination $remotePath -ToSession $session -Force
    }
    
    # Copy scripts directory
    Write-Host "  Copying scripts directory..."
    Copy-Item -Path "C:\code\setuplab\scripts" -Destination "C:\SetupLab" -ToSession $session -Recurse -Force
    
    # Copy modules directory
    Write-Host "  Copying modules directory..."
    Copy-Item -Path "C:\code\setuplab\modules" -Destination "C:\SetupLab" -ToSession $session -Recurse -Force
    
    # Run main.ps1
    Write-Host "`nRunning main.ps1 installation..." -ForegroundColor Yellow
    $installResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Set-Location "C:\SetupLab"
            
            # Run main.ps1
            & .\main.ps1
            
            return $true
        }
        catch {
            Write-Error "Installation failed: $_"
            return $false
        }
    }
    
    if ($installResult) {
        Write-Host "`nMain.ps1 execution completed" -ForegroundColor Green
    } else {
        Write-Host "`nMain.ps1 execution failed" -ForegroundColor Red
    }
    
    # Wait for installations to complete
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
                $wtAppx = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                $found = $wtInApps -or $wtExe -or ($null -ne $wtAppx)
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
    
    # Display results with visual bar
    Write-Host ""
    foreach ($i in 1..16) {
        Write-Host -NoNewline "█" -ForegroundColor $(if ($i -le $finalResults.Installed) { "Green" } else { "Red" })
    }
    Write-Host ""
    
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
        Write-Host "`nSUCCESS! 100% AUTOMATED INSTALLATION ACHIEVED!" -ForegroundColor Green
        Write-Host "All 16 applications installed without any manual intervention!" -ForegroundColor Green
        Write-Host "The SetupLab script is fully automated and ready for production use!" -ForegroundColor Green
    }
    else {
        Write-Host "`nInstallation incomplete. Missing apps:" -ForegroundColor Red
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