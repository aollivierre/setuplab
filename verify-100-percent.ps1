# Verify 100% installation on fresh VM
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "VERIFYING 100% INSTALLATION" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $checks = @{
            "01. 7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "02. Git" = "C:\Program Files\Git\bin\git.exe"
            "03. VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "04. Node.js" = "C:\Program Files\nodejs\node.exe"
            "05. GitHub Desktop" = @(
                "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe",
                "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe"
            )
            "06. GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "07. PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "08. Chrome" = @(
                "C:\Program Files\Google\Chrome\Application\chrome.exe",
                "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            )
            "09. Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "10. ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "11. Everything" = "C:\Program Files\Everything\Everything.exe"
            "12. FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "13. VC++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "14. Warp" = @(
                "$env:LOCALAPPDATA\Programs\Warp\Warp.exe",
                "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe"
            )
            "15. Windows Terminal" = $null  # Special handling
            "16. Claude CLI" = @(
                "$env:APPDATA\npm\claude.cmd",
                "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
            )
        }
        
        $installed = 0
        $details = @()
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "15. Windows Terminal") {
                # Multiple detection methods
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
            $details += [PSCustomObject]@{
                Name = $app.Key
                Installed = $found
            }
        }
        
        @{
            Details = $details | Sort-Object Name
            Installed = $installed
            Total = $checks.Count
        }
    }
    
    # Display results
    Write-Host ""
    foreach ($app in $results.Details) {
        $icon = if ($app.Installed) { "[OK]" } else { "[X]" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0} {1}" -f $icon, $app.Name) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
    
    Write-Host "`n=====================================" -ForegroundColor Cyan
    Write-Host "RESULT: $($results.Installed)/$($results.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "=====================================" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** PERFECT! 100% SUCCESS! ***" -ForegroundColor Green
        Write-Host "All 16 applications installed on fresh VM!" -ForegroundColor Green
        Write-Host "SetupLab is production-ready!" -ForegroundColor Green
    }
    elseif ($results.Installed -eq 15) {
        Write-Host "`nExcellent! 15/16 apps installed." -ForegroundColor Yellow
        Write-Host "Only missing:" -ForegroundColor Yellow
        $results.Details | Where-Object { -not $_.Installed } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
    }
    
    Remove-PSSession $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }
}