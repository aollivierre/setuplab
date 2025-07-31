# Test installation without Node.js to see if it completes
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST WITHOUT NODE.JS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing if installation completes when Node.js is disabled" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected successfully" -ForegroundColor Green
    
    # Clean up
    Write-Host "`nCleaning up remote directory..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        if (Test-Path "C:\SetupLab") {
            Remove-Item "C:\SetupLab" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "C:\SetupLab" -Force | Out-Null
        
        # Kill any stuck processes
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    
    # Copy files
    Write-Host "Copying required files..." -ForegroundColor Yellow
    $filesToCopy = @(
        "main.ps1",
        "software-config-no-nodejs.json",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "Download-Sysinternals.ps1",
        "install-claude-cli.ps1"
    )
    
    foreach ($file in $filesToCopy) {
        $localPath = "C:\code\setuplab\$file"
        if (Test-Path $localPath) {
            if ($file -eq "software-config-no-nodejs.json") {
                # Copy as software-config.json
                $remotePath = "C:\SetupLab\software-config.json"
            } else {
                $remotePath = "C:\SetupLab\$file"
            }
            Write-Host "  Copying $file..."
            Copy-Item -Path $localPath -Destination $remotePath -ToSession $session -Force
        }
    }
    
    # Run installation
    Write-Host "`nRunning installation (Node.js disabled)..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    $installJob = Invoke-Command -Session $session -AsJob -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-Location "C:\SetupLab"
        
        # Run main.ps1
        & .\main.ps1
    }
    
    # Monitor job
    Write-Host "Installation job started (ID: $($installJob.Id))" -ForegroundColor Green
    Write-Host "Monitoring progress..." -ForegroundColor Yellow
    
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
    
    Write-Host "`nJob completed with state: $($installJob.State)" -ForegroundColor $(if ($installJob.State -eq 'Completed') { 'Green' } else { 'Red' })
    Remove-Job -Job $installJob
    
    # Wait for completion
    Start-Sleep -Seconds 10
    
    # Check results
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "VERIFICATION (14 apps, Node.js and Claude CLI disabled)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
            "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "GitHub Desktop" = @("$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe", "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe")
            "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
            "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "VC++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp" = @("$env:LOCALAPPDATA\Programs\Warp\Warp.exe", "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe")
            "Windows Terminal" = $null
        }
        
        $installed = 0
        $results = @()
        
        foreach ($app in $apps.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "Windows Terminal") {
                $found = (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue) -ne $null
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
        
        @{
            Results = $results | Sort-Object Name
            Installed = $installed
            Total = $apps.Count
        }
    }
    
    # Display results
    foreach ($app in $results.Results) {
        $status = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RESULT: $($results.Installed)/$($results.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($results.Installed -eq $results.Total) {
        Write-Host "`nSUCCESS! All 14 apps installed (Node.js and Claude CLI were disabled)" -ForegroundColor Green
        Write-Host "This proves the installer works when Node.js is excluded!" -ForegroundColor Green
    } else {
        Write-Host "`nStill missing some apps. Installation may have stopped early." -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}