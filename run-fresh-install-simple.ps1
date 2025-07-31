# Simple fresh install test - copies minimal required files
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SIMPLE FRESH INSTALLATION TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $RemoteComputer" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected successfully" -ForegroundColor Green
    
    # Create directory
    Write-Host "`nCreating remote directory..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        if (Test-Path "C:\SetupLab") {
            Remove-Item "C:\SetupLab" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "C:\SetupLab" -Force | Out-Null
    }
    
    # Copy essential files
    Write-Host "Copying essential files..." -ForegroundColor Yellow
    $essentialFiles = @(
        "main.ps1",
        "software-config.json",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "Download-Sysinternals.ps1",
        "install-claude-cli.ps1"
    )
    
    foreach ($file in $essentialFiles) {
        $localPath = "C:\code\setuplab\$file"
        if (Test-Path $localPath) {
            $remotePath = "C:\SetupLab\$file"
            Write-Host "  Copying $file..."
            Copy-Item -Path $localPath -Destination $remotePath -ToSession $session -Force
        }
    }
    
    # Run installation
    Write-Host "`nRunning installation..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-Location "C:\SetupLab"
        
        # Run main.ps1
        & .\main.ps1
    }
    
    # Wait for completion
    Write-Host "`nWaiting for installations to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Check results
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "VERIFICATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $results = Invoke-Command -Session $session -ScriptBlock {
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
    
    # Display results
    foreach ($app in $results.Results) {
        $status = if ($app.Installed) { "INSTALLED" } else { "MISSING" }
        $color = if ($app.Installed) { "Green" } else { "Red" }
        Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
    }
    
    $percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RESULT: $($results.Installed)/$($results.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($percentage -eq 100) {
        Write-Host "`n*** 100% SUCCESS ACHIEVED! ***" -ForegroundColor Green
        Write-Host "All applications installed automatically!" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}