# Complete remaining installations on remote VM
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "COMPLETING REMAINING INSTALLATIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected successfully" -ForegroundColor Green
    
    # Kill any stuck processes first
    Write-Host "`nKilling any stuck installers..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue | 
            Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-5) } | 
            Stop-Process -Force
        Start-Sleep -Seconds 2
    }
    
    # Copy the direct installer script
    Write-Host "Copying direct installer script..." -ForegroundColor Yellow
    $localScript = "C:\code\setuplab\install-remaining-apps-direct.ps1"
    $remoteScript = "C:\SetupLab\install-remaining-apps-direct.ps1"
    
    if (Test-Path $localScript) {
        Copy-Item -Path $localScript -Destination $remoteScript -ToSession $session -Force
        Write-Host "Script copied successfully" -ForegroundColor Green
    }
    
    # Run the direct installer
    Write-Host "`nRunning direct installer for remaining apps..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-Location "C:\SetupLab"
        
        # Run the direct installer
        & .\install-remaining-apps-direct.ps1
    }
    
    # Final check after completion
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "FINAL STATUS CHECK" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $finalStatus = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
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
            "VC++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp" = @("$env:LOCALAPPDATA\Programs\Warp\Warp.exe", "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe")
            "Windows Terminal" = $null
            "Claude CLI" = @("$env:APPDATA\npm\claude.cmd", "C:\Users\administrator\AppData\Roaming\npm\claude.cmd")
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
    
    # Display final results
    Write-Host ""
    foreach ($i in 1..16) {
        Write-Host -NoNewline "#" -ForegroundColor $(if ($i -le $finalStatus.Installed) { "Green" } else { "Red" })
    }
    Write-Host " $($finalStatus.Installed)/16"
    
    foreach ($app in $finalStatus.Results) {
        $status = if ($app.Installed) { "INSTALLED" } else { "MISSING" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($finalStatus.Installed / $finalStatus.Total) * 100, 1)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "FINAL RESULT: $($finalStatus.Installed)/$($finalStatus.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** 100% AUTOMATED INSTALLATION ACHIEVED! ***" -ForegroundColor Green
        Write-Host "All 16 applications successfully installed!" -ForegroundColor Green
        Write-Host "The SetupLab script is ready for production use!" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}