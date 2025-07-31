# Final test for 100% installation success
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n####################################################" -ForegroundColor Cyan
Write-Host "#     FINAL 100% INSTALLATION TEST                 #" -ForegroundColor Cyan
Write-Host "####################################################" -ForegroundColor Cyan
Write-Host "# Target: $RemoteComputer" -ForegroundColor Yellow
Write-Host "# Fixes Applied:" -ForegroundColor Yellow
Write-Host "#   - Node.js: Using /qn flag only" -ForegroundColor Green
Write-Host "#   - MSI: Handling exit codes 1603/3010" -ForegroundColor Green
Write-Host "#   - Warp: Using correct /VERYSILENT flag" -ForegroundColor Green
Write-Host "####################################################`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "[OK] Connected to remote VM" -ForegroundColor Green
    
    # Clean environment
    Write-Host "`n[STEP 1] Cleaning environment..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Kill stuck processes
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue | 
            Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-5) } | 
            Stop-Process -Force
        
        # Clean directory
        if (Test-Path "C:\SetupLab") {
            Remove-Item "C:\SetupLab" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "C:\SetupLab" -Force | Out-Null
        
        # Clean logs
        if (Test-Path "C:\ProgramData\SetupLab\Logs") {
            Get-ChildItem "C:\ProgramData\SetupLab\Logs\*.log" | Remove-Item -Force
        }
    }
    Write-Host "[OK] Environment cleaned" -ForegroundColor Green
    
    # Copy files
    Write-Host "`n[STEP 2] Copying setup files..." -ForegroundColor Yellow
    $files = @(
        "main.ps1",
        "software-config.json",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "Download-Sysinternals.ps1",
        "install-claude-cli.ps1"
    )
    
    foreach ($file in $files) {
        Copy-Item -Path "C:\code\setuplab\$file" -Destination "C:\SetupLab\$file" -ToSession $session -Force
        Write-Host "  [OK] $file" -ForegroundColor Gray
    }
    Write-Host "[OK] Files copied" -ForegroundColor Green
    
    # Run installation
    Write-Host "`n[STEP 3] Starting installation..." -ForegroundColor Yellow
    Write-Host "This will install all 16 applications automatically" -ForegroundColor Gray
    
    $startTime = Get-Date
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-Location "C:\SetupLab"
        & .\main.ps1
    }
    
    $duration = (Get-Date) - $startTime
    Write-Host "`n[OK] Installation completed in $($duration.ToString('mm\:ss'))" -ForegroundColor Green
    
    # Final verification
    Write-Host "`n[STEP 4] Verifying installations..." -ForegroundColor Yellow
    $results = Invoke-Command -Session $session -ScriptBlock {
        $checks = @{
            "01. 7-Zip" = { Test-Path "C:\Program Files\7-Zip\7z.exe" }
            "02. Git" = { Test-Path "C:\Program Files\Git\bin\git.exe" }
            "03. VS Code" = { Test-Path "C:\Program Files\Microsoft VS Code\Code.exe" }
            "04. Node.js" = { Test-Path "C:\Program Files\nodejs\node.exe" }
            "05. GitHub Desktop" = { 
                (Test-Path "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe") -or 
                (Test-Path "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe")
            }
            "06. GitHub CLI" = { Test-Path "C:\Program Files\GitHub CLI\gh.exe" }
            "07. PowerShell 7" = { Test-Path "C:\Program Files\PowerShell\7\pwsh.exe" }
            "08. Chrome" = { 
                (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or 
                (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            }
            "09. Firefox" = { Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe" }
            "10. ShareX" = { Test-Path "C:\Program Files\ShareX\ShareX.exe" }
            "11. Everything" = { Test-Path "C:\Program Files\Everything\Everything.exe" }
            "12. FileLocator Pro" = { Test-Path "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe" }
            "13. VC++ Redist" = { Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" }
            "14. Warp Terminal" = { 
                (Test-Path "$env:LOCALAPPDATA\Programs\Warp\Warp.exe") -or 
                (Test-Path "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe")
            }
            "15. Windows Terminal" = { 
                $null -ne (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue)
            }
            "16. Claude CLI" = { 
                (Test-Path "$env:APPDATA\npm\claude.cmd") -or 
                (Test-Path "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
            }
        }
        
        $results = @()
        $installed = 0
        
        foreach ($check in $checks.GetEnumerator()) {
            $isInstalled = & $check.Value
            if ($isInstalled) { $installed++ }
            
            $results += [PSCustomObject]@{
                Name = $check.Key
                Installed = $isInstalled
            }
        }
        
        # Get Node.js version if installed
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
    Write-Host "`n=====================================================" -ForegroundColor Cyan
    Write-Host "INSTALLATION RESULTS" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    
    foreach ($app in $results.Results) {
        $icon = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0} {1}" -f $icon, $app.Name) -ForegroundColor $color
    }
    
    if ($results.NodeVersion) {
        Write-Host "`nNode.js version: $($results.NodeVersion)" -ForegroundColor Cyan
    }
    
    Write-Host "`n=====================================================" -ForegroundColor Cyan
    $percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
    
    # Progress bar
    Write-Host -NoNewline "Progress: ["
    for ($i = 1; $i -le 16; $i++) {
        if ($i -le $results.Installed) {
            Write-Host -NoNewline "#" -ForegroundColor Green
        } else {
            Write-Host -NoNewline "-" -ForegroundColor Red
        }
    }
    Write-Host "] $($results.Installed)/$($results.Total) ($percentage%)"
    
    Write-Host "=====================================================" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`nCONGRATULATIONS! 100% SUCCESS ACHIEVED!" -ForegroundColor Green
        Write-Host "All 16 applications installed successfully!" -ForegroundColor Green
        Write-Host "The SetupLab installer is working perfectly!" -ForegroundColor Green
        Write-Host "`nKey fixes that made this possible:" -ForegroundColor Yellow
        Write-Host "  - Node.js: Simplified to /qn flag only" -ForegroundColor Gray
        Write-Host "  - MSI: Accept exit codes 1603/3010 as success" -ForegroundColor Gray
        Write-Host "  - Warp: Use /VERYSILENT instead of /S" -ForegroundColor Gray
        Write-Host "  - Validation: Trust post-install checks over exit codes" -ForegroundColor Gray
    }
    else {
        Write-Host "`nInstallation incomplete. Missing applications:" -ForegroundColor Red
        $results.Results | Where-Object { -not $_.Installed } | ForEach-Object {
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