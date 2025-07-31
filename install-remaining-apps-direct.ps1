# Direct installer for remaining apps - minimal dependencies
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nDirect Installer for Remaining Applications" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

$session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop

# Chrome
Write-Host "`n[1/8] Installing Chrome..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        $chromeInstalled = (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        if ($chromeInstalled) {
            Write-Host "  Chrome is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
        $installer = "$env:TEMP\chrome_installer.exe"
        
        Write-Host "  Downloading Chrome..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        
        Write-Host "  Installing Chrome..."
        Start-Process -FilePath $installer -ArgumentList "/silent /install" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        $success = (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        if ($success) {
            Write-Host "  Chrome installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Chrome installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Firefox
Write-Host "`n[2/8] Installing Firefox..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        if (Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe") {
            Write-Host "  Firefox is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
        $installer = "$env:TEMP\firefox_installer.exe"
        
        Write-Host "  Downloading Firefox..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $installer)
        
        Write-Host "  Installing Firefox..."
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        if (Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe") {
            Write-Host "  Firefox installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Firefox installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Everything
Write-Host "`n[3/8] Installing Everything..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        if (Test-Path "C:\Program Files\Everything\Everything.exe") {
            Write-Host "  Everything is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://www.voidtools.com/Everything-1.4.1.1028.x64-Setup.exe"
        $installer = "$env:TEMP\everything_installer.exe"
        
        Write-Host "  Downloading Everything..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        
        Write-Host "  Installing Everything..."
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        if (Test-Path "C:\Program Files\Everything\Everything.exe") {
            Write-Host "  Everything installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Everything installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# ShareX
Write-Host "`n[4/8] Installing ShareX..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        if (Test-Path "C:\Program Files\ShareX\ShareX.exe") {
            Write-Host "  ShareX is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://github.com/ShareX/ShareX/releases/download/v17.1.0/ShareX-17.1.0-setup.exe"
        $installer = "$env:TEMP\sharex_installer.exe"
        
        Write-Host "  Downloading ShareX..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        
        Write-Host "  Installing ShareX..."
        Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        if (Test-Path "C:\Program Files\ShareX\ShareX.exe") {
            Write-Host "  ShareX installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  ShareX installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# FileLocator Pro
Write-Host "`n[5/8] Installing FileLocator Pro..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        if (Test-Path "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe") {
            Write-Host "  FileLocator Pro is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
        $installer = "$env:TEMP\filelocator_installer.exe"
        
        Write-Host "  Downloading FileLocator Pro..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        
        Write-Host "  Installing FileLocator Pro..."
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        # Wait extra time for FileLocator Pro
        Start-Sleep -Seconds 10
        
        if (Test-Path "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe") {
            Write-Host "  FileLocator Pro installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  FileLocator Pro installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Visual C++ Redistributables
Write-Host "`n[6/8] Installing Visual C++ Redistributables..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64") {
            Write-Host "  Visual C++ Redistributables already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $installer = "$env:TEMP\vcredist_installer.exe"
        
        Write-Host "  Downloading Visual C++ Redistributables..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        
        Write-Host "  Installing Visual C++ Redistributables..."
        Start-Process -FilePath $installer -ArgumentList "/quiet /norestart" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64") {
            Write-Host "  Visual C++ Redistributables installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Visual C++ Redistributables installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Warp Terminal
Write-Host "`n[7/8] Installing Warp Terminal..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        $warpPath = "$env:LOCALAPPDATA\Programs\Warp\Warp.exe"
        if (Test-Path $warpPath) {
            Write-Host "  Warp Terminal is already installed" -ForegroundColor Green
            return
        }
        
        $url = "https://releases.warp.dev/stable/v0.2025.07.09.08.11.stable_01/WarpSetup.exe"
        $installer = "$env:TEMP\warp_installer.exe"
        
        Write-Host "  Downloading Warp Terminal..."
        # Use WebClient for Warp as it sometimes has issues with Invoke-WebRequest
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $installer)
        
        Write-Host "  Installing Warp Terminal..."
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        # Wait for Warp installation
        Start-Sleep -Seconds 5
        
        if (Test-Path $warpPath) {
            Write-Host "  Warp Terminal installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Warp Terminal installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Claude CLI
Write-Host "`n[8/8] Installing Claude CLI..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        if (Test-Path $claudePath) {
            Write-Host "  Claude CLI is already installed" -ForegroundColor Green
            return
        }
        
        # Check if npm exists
        $npmPath = "C:\Program Files\nodejs\npm.cmd"
        if (-not (Test-Path $npmPath)) {
            Write-Host "  npm not found - cannot install Claude CLI" -ForegroundColor Red
            return
        }
        
        Write-Host "  Installing Claude CLI via npm..."
        $env:Path += ";C:\Program Files\nodejs"
        
        # Run npm install
        $npmProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$npmPath`" install -g @anthropic-ai/claude-code" -Wait -PassThru -NoNewWindow
        
        # Wait for installation
        Start-Sleep -Seconds 5
        
        if (Test-Path $claudePath) {
            Write-Host "  Claude CLI installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Claude CLI installation failed!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Final check
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "FINAL VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$results = Invoke-Command -Session $session -ScriptBlock {
    $checks = @{
        "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
        "Git" = "C:\Program Files\Git\bin\git.exe"
        "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
        "Node.js" = "C:\Program Files\nodejs\node.exe"
        "GitHub Desktop" = "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe"
        "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
        "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
        "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
        "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
        "Everything" = "C:\Program Files\Everything\Everything.exe"
        "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
        "Visual C++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
        "Warp Terminal" = "$env:LOCALAPPDATA\Programs\Warp\Warp.exe"
        "Windows Terminal" = $null
        "Claude CLI" = "$env:APPDATA\npm\claude.cmd"
    }
    
    $installed = 0
    $results = @()
    
    foreach ($app in $checks.GetEnumerator()) {
        $found = $false
        
        if ($app.Key -eq "Windows Terminal") {
            $wtCheck = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
            $found = $null -ne $wtCheck
        }
        elseif ($app.Value -match "^HKLM:") {
            $found = Test-Path $app.Value
        }
        elseif ($app.Value -is [array]) {
            foreach ($path in $app.Value) {
                if (Test-Path $path) {
                    $found = $true
                    break
                }
            }
        }
        else {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($app.Value)
            $found = Test-Path $expandedPath
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

foreach ($app in $results.Results) {
    $status = if ($app.Installed) { "INSTALLED" } else { "MISSING" }
    $color = if ($app.Installed) { "Green" } else { "Red" }
    Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
}

$percentage = [math]::Round(($results.Installed / $results.Total) * 100, 1)
Write-Host "`nSUMMARY: $($results.Installed)/$($results.Total) installed ($percentage%)" -ForegroundColor Yellow

if ($results.Installed -eq $results.Total) {
    Write-Host "`n*** 100% SUCCESS RATE ACHIEVED! ***" -ForegroundColor Green
    Write-Host "All applications successfully installed!" -ForegroundColor Green
}

Remove-PSSession -Session $session