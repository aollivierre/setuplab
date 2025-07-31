# Test fresh VM using main.ps1 directly (avoiding web launcher issues)
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n##############################################################" -ForegroundColor Cyan
Write-Host "#            FRESH VM TEST - DIRECT MAIN.PS1                 #" -ForegroundColor Cyan
Write-Host "##############################################################" -ForegroundColor Cyan
Write-Host "# VM: $RemoteComputer (Fresh from checkpoint)" -ForegroundColor Yellow
Write-Host "# Method: Copy files and run main.ps1 directly" -ForegroundColor Yellow
Write-Host "# Expected: 100% automated installation" -ForegroundColor Yellow
Write-Host "##############################################################`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "[OK] Connected to fresh VM" -ForegroundColor Green
    
    # Verify fresh state
    Write-Host "`n[STEP 1] Verifying fresh VM state..." -ForegroundColor Yellow
    $preCheck = Invoke-Command -Session $session -ScriptBlock {
        $count = 0
        @("Git", "Node.js", "7-Zip", "Visual Studio Code") | ForEach-Object {
            if (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*$_*" }) {
                $count++
            }
        }
        return $count
    }
    
    Write-Host "[OK] Found $preCheck pre-installed apps (should be 0 or 1 for Windows Terminal)" -ForegroundColor $(if ($preCheck -le 1) { "Green" } else { "Yellow" })
    
    # Clean and prepare
    Write-Host "`n[STEP 2] Preparing remote environment..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Kill any stuck processes
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue | 
            Where-Object { $_.ProcessName -ne "setuplab01" } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Create directory
        if (Test-Path "C:\SetupLab") {
            Remove-Item "C:\SetupLab" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "C:\SetupLab" -Force | Out-Null
        
        # Clean logs
        if (Test-Path "C:\ProgramData\SetupLab\Logs") {
            Get-ChildItem "C:\ProgramData\SetupLab\Logs\*.log" | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "[OK] Environment prepared" -ForegroundColor Green
    
    # Copy required files
    Write-Host "`n[STEP 3] Copying setup files..." -ForegroundColor Yellow
    $requiredFiles = @(
        "main.ps1",
        "software-config.json",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "Download-Sysinternals.ps1",
        "install-claude-cli.ps1"
    )
    
    foreach ($file in $requiredFiles) {
        $sourcePath = Join-Path "C:\code\setuplab" $file
        $destPath = "C:\SetupLab\$file"
        
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destPath -ToSession $session -Force
            Write-Host "  [OK] $file" -ForegroundColor Gray
        } else {
            Write-Host "  [WARN] $file not found" -ForegroundColor Yellow
        }
    }
    
    # Run installation
    Write-Host "`n[STEP 4] Starting installation..." -ForegroundColor Yellow
    Write-Host "This will install all 16 applications automatically" -ForegroundColor Gray
    
    $startTime = Get-Date
    
    # Run main.ps1 and capture output
    $output = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-Location "C:\SetupLab"
        
        # Capture both output and errors
        $result = @{
            Output = @()
            Success = $true
            Error = $null
        }
        
        try {
            # Run main.ps1 and capture output
            $scriptOutput = & .\main.ps1 2>&1
            $result.Output = $scriptOutput
            
            # Check if there were any errors
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                $result.Success = $false
            }
        }
        catch {
            $result.Success = $false
            $result.Error = $_.Exception.Message
        }
        
        return $result
    }
    
    # Display output
    if ($output.Output) {
        foreach ($line in $output.Output) {
            Write-Host $line
        }
    }
    
    if (-not $output.Success) {
        Write-Host "`n[WARN] Installation reported issues" -ForegroundColor Yellow
        if ($output.Error) {
            Write-Host "Error: $($output.Error)" -ForegroundColor Red
        }
    }
    
    $duration = (Get-Date) - $startTime
    Write-Host "`n[INFO] Installation completed in $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    
    # Wait for everything to settle
    Write-Host "`n[STEP 5] Waiting for post-installation tasks..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
    # Final verification
    Write-Host "`n[STEP 6] Final verification..." -ForegroundColor Yellow
    
    $finalResults = Invoke-Command -Session $session -ScriptBlock {
        $apps = [ordered]@{
            "01. 7-Zip" = { Test-Path "C:\Program Files\7-Zip\7z.exe" }
            "02. Git" = { Test-Path "C:\Program Files\Git\bin\git.exe" }
            "03. VS Code" = { Test-Path "C:\Program Files\Microsoft VS Code\Code.exe" }
            "04. Node.js" = { Test-Path "C:\Program Files\nodejs\node.exe" }
            "05. GitHub Desktop" = { 
                (Test-Path "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe") -or 
                (Test-Path "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe") -or
                (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*GitHub Desktop*" })
            }
            "06. GitHub CLI" = { Test-Path "C:\Program Files\GitHub CLI\gh.exe" }
            "07. PowerShell 7" = { Test-Path "C:\Program Files\PowerShell\7\pwsh.exe" }
            "08. Chrome" = { 
                (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or 
                (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") -or
                (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*Google Chrome*" })
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
                (Test-Path "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*") -or
                (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe") -or
                ($null -ne (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue))
            }
            "16. Claude CLI" = { 
                (Test-Path "$env:APPDATA\npm\claude.cmd") -or 
                (Test-Path "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
            }
        }
        
        $results = @()
        $installed = 0
        
        foreach ($app in $apps.GetEnumerator()) {
            $isInstalled = & $app.Value
            if ($isInstalled) { $installed++ }
            
            $results += [PSCustomObject]@{
                Name = $app.Key
                Installed = $isInstalled
            }
        }
        
        # Get versions
        $versions = @{}
        if (Test-Path "C:\Program Files\nodejs\node.exe") {
            $versions["Node.js"] = & "C:\Program Files\nodejs\node.exe" --version 2>$null
        }
        if (Test-Path "C:\Program Files\Git\bin\git.exe") {
            $gitOut = & "C:\Program Files\Git\bin\git.exe" --version 2>$null
            if ($gitOut -match "version (.+)") {
                $versions["Git"] = $matches[1]
            }
        }
        
        @{
            Results = $results
            Installed = $installed
            Total = $apps.Count
            Versions = $versions
        }
    }
    
    # Display results
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "#                  FINAL RESULTS                             #" -ForegroundColor Cyan
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    # Visual progress bar
    Write-Host -NoNewline "`n["
    for ($i = 1; $i -le 16; $i++) {
        if ($i -le $finalResults.Installed) {
            Write-Host -NoNewline "#" -ForegroundColor Green
        } else {
            Write-Host -NoNewline "-" -ForegroundColor Red
        }
    }
    Write-Host "] $($finalResults.Installed)/16`n"
    
    # Detailed results
    foreach ($app in $finalResults.Results) {
        $icon = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0} {1}" -f $icon, $app.Name) -ForegroundColor $color
    }
    
    # Show versions
    if ($finalResults.Versions.Count -gt 0) {
        Write-Host "`nVersions:" -ForegroundColor Cyan
        foreach ($ver in $finalResults.Versions.GetEnumerator()) {
            Write-Host "  $($ver.Key): $($ver.Value)" -ForegroundColor Gray
        }
    }
    
    $percentage = [math]::Round(($finalResults.Installed / $finalResults.Total) * 100, 1)
    
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "# RESULT: $($finalResults.Installed)/$($finalResults.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 90) { "Yellow" } else { "Red" })
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** PERFECT! 100% SUCCESS! ***" -ForegroundColor Green
        Write-Host "All 16 applications installed on fresh VM!" -ForegroundColor Green
        Write-Host "Total time: $($duration.ToString('mm\:ss'))" -ForegroundColor Green
        Write-Host "`nThe SetupLab installer is production-ready!" -ForegroundColor Green
    }
    elseif ($percentage -ge 90) {
        Write-Host "`nExcellent result! Nearly complete." -ForegroundColor Yellow
        Write-Host "Missing only:" -ForegroundColor Yellow
        $finalResults.Results | Where-Object { -not $_.Installed } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`nInstallation incomplete." -ForegroundColor Red
        Write-Host "Missing applications:" -ForegroundColor Red
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