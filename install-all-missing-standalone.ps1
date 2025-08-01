# Standalone installer for missing apps - no module dependencies
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nStandalone Installer for Missing Applications" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Set execution policy on remote machine
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    }
    
    # Define all installers with direct download logic
    $installers = @(
        @{
            Name = "Chrome"
            Url = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
            Args = "/silent /install"
            Type = "EXE"
            VerifyPath = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
        },
        @{
            Name = "Firefox"
            Url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
            Args = "/S"
            Type = "EXE"
            VerifyPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
        },
        @{
            Name = "Everything"
            Url = "https://www.voidtools.com/Everything-1.4.1.1028.x64-Setup.exe"
            Args = "/S"
            Type = "EXE"
            VerifyPath = "C:\Program Files\Everything\Everything.exe"
        },
        @{
            Name = "ShareX"
            Url = "https://github.com/ShareX/ShareX/releases/download/v17.1.0/ShareX-17.1.0-setup.exe"
            Args = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
            Type = "EXE"
            VerifyPath = "C:\Program Files\ShareX\ShareX.exe"
        },
        @{
            Name = "FileLocator Pro"
            Url = "https://download.mythicsoft.com/flp/3522/filelocator_3522.exe"
            Args = "/S"
            Type = "EXE"
            VerifyPath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
        },
        @{
            Name = "Visual C++ Redistributables"
            Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            Args = "/quiet /norestart"
            Type = "EXE"
            VerifyPath = "REGISTRY:HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
        },
        @{
            Name = "Warp Terminal"
            Url = "https://releases.warp.dev/stable/v0.2025.07.09.08.11.stable_01/WarpSetup.exe"
            Args = "/S"
            Type = "EXE"
            VerifyPath = "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe"
        }
    )
    
    # Install each missing app
    foreach ($installer in $installers) {
        Write-Host "Installing $($installer.Name)..." -ForegroundColor Yellow
        
        $result = Invoke-Command -Session $session -ScriptBlock {
            param($app)
            
            try {
                # Check if already installed
                $installed = $false
                if ($app.VerifyPath -match "^REGISTRY:") {
                    $regPath = $app.VerifyPath -replace "^REGISTRY:", ""
                    $installed = Test-Path $regPath
                }
                elseif ($app.VerifyPath -is [array]) {
                    foreach ($path in $app.VerifyPath) {
                        if (Test-Path $path) {
                            $installed = $true
                            break
                        }
                    }
                }
                else {
                    $installed = Test-Path $app.VerifyPath
                }
                
                if ($installed) {
                    return @{ Success = $true; Message = "$($app.Name) is already installed" }
                }
                
                # Download installer
                $tempFile = Join-Path $env:TEMP "$($app.Name)_installer.$($app.Type.ToLower())"
                
                Write-Host "  Downloading $($app.Name)..." -NoNewline
                
                # Try BITS first
                try {
                    Start-BitsTransfer -Source $app.Url -Destination $tempFile -ErrorAction Stop
                    Write-Host " Done (BITS)" -ForegroundColor Green
                }
                catch {
                    # Fallback to WebClient
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($app.Url, $tempFile)
                    Write-Host " Done (WebClient)" -ForegroundColor Green
                }
                
                if (-not (Test-Path $tempFile)) {
                    throw "Download failed"
                }
                
                # Install
                Write-Host "  Installing $($app.Name)..." -NoNewline
                
                if ($app.Type -eq "MSI") {
                    $args = @("/i", "`"$tempFile`"") + ($app.Args -split " ")
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru
                }
                else {
                    $process = Start-Process -FilePath $tempFile -ArgumentList $app.Args -Wait -PassThru
                }
                
                # Cleanup
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                # Wait a moment for installation to complete
                Start-Sleep -Seconds 3
                
                # Verify installation
                $installed = $false
                if ($app.VerifyPath -match "^REGISTRY:") {
                    $regPath = $app.VerifyPath -replace "^REGISTRY:", ""
                    $installed = Test-Path $regPath
                }
                elseif ($app.VerifyPath -is [array]) {
                    foreach ($path in $app.VerifyPath) {
                        if (Test-Path $path) {
                            $installed = $true
                            break
                        }
                    }
                }
                else {
                    $installed = Test-Path $app.VerifyPath
                }
                
                if ($installed) {
                    Write-Host " Success" -ForegroundColor Green
                    return @{ Success = $true; Message = "$($app.Name) installed successfully" }
                }
                else {
                    Write-Host " Failed (not found after install)" -ForegroundColor Red
                    return @{ Success = $false; Message = "Installation completed but verification failed" }
                }
            }
            catch {
                Write-Host " Error" -ForegroundColor Red
                return @{ Success = $false; Message = $_.Exception.Message }
            }
        } -ArgumentList $installer
        
        if ($result.Success) {
            Write-Host "  [OK] $($result.Message)" -ForegroundColor Green
        }
        else {
            Write-Host "  [FAIL] $($result.Message)" -ForegroundColor Red
        }
    }
    
    # Install Claude CLI separately (requires npm)
    Write-Host "`nInstalling Claude CLI..." -ForegroundColor Yellow
    
    $claudeResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Update PATH to include Node.js
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:Path = "$machinePath;$userPath"
            
            # Check if npm is available
            $npmPath = "C:\Program Files\nodejs\npm.cmd"
            if (-not (Test-Path $npmPath)) {
                return @{ Success = $false; Message = "npm not found at expected location" }
            }
            
            # Install Claude CLI
            Write-Host "  Running npm install..." -NoNewline
            $process = Start-Process -FilePath $npmPath -ArgumentList "install -g @anthropic-ai/claude-code" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Host " Done" -ForegroundColor Green
                
                # Verify installation
                $claudePath = "$env:APPDATA\npm\claude.cmd"
                if (Test-Path $claudePath) {
                    return @{ Success = $true; Message = "Claude CLI installed successfully" }
                }
                else {
                    return @{ Success = $false; Message = "Installation completed but claude.cmd not found" }
                }
            }
            else {
                Write-Host " Failed" -ForegroundColor Red
                return @{ Success = $false; Message = "npm install failed with exit code $($process.ExitCode)" }
            }
        }
        catch {
            return @{ Success = $false; Message = $_.Exception.Message }
        }
    }
    
    if ($claudeResult.Success) {
        Write-Host "  [OK] $($claudeResult.Message)" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] $($claudeResult.Message)" -ForegroundColor Red
    }
    
    # Final verification
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "FINAL VERIFICATION" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    $finalCheck = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
            "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "GitHub Desktop" = @("C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe", "C:\Users\$env:USERNAME\AppData\Local\GitHubDesktop\GitHubDesktop.exe")
            "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
            "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "Visual C++ Redistributables" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp Terminal" = @("C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe", "C:\Users\$env:USERNAME\AppData\Local\Programs\Warp\Warp.exe")
            "Windows Terminal" = $null  # Special check
            "Claude CLI" = @("C:\Users\administrator\AppData\Roaming\npm\claude.cmd", "C:\Users\$env:USERNAME\AppData\Roaming\npm\claude.cmd")
        }
        
        $results = @{}
        $installed = 0
        $missing = @()
        
        foreach ($app in $apps.GetEnumerator()) {
            $found = $false
            
            if ($app.Key -eq "Windows Terminal") {
                # Special check for Windows Terminal
                $wtInstalled = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                $found = $null -ne $wtInstalled
            }
            elseif ($app.Value -match "^HKLM:") {
                $found = Test-Path $app.Value
            }
            elseif ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)
                    if (Test-Path $expandedPath) {
                        $found = $true
                        break
                    }
                }
            }
            elseif ($app.Value) {
                $found = Test-Path $app.Value
            }
            
            $results[$app.Key] = $found
            if ($found) {
                $installed++
            } else {
                $missing += $app.Key
            }
        }
        
        @{
            Results = $results
            Installed = $installed
            Missing = $missing
            Total = $apps.Count
        }
    }
    
    foreach ($app in $finalCheck.Results.GetEnumerator() | Sort-Object Key) {
        $status = if ($app.Value) { "INSTALLED" } else { "MISSING" }
        $color = if ($app.Value) { "Green" } else { "Red" }
        Write-Host ("{0,-30} : {1}" -f $app.Key, $status) -ForegroundColor $color
    }
    
    Write-Host "`nSUMMARY:" -ForegroundColor Yellow
    Write-Host "Total: $($finalCheck.Total)" -ForegroundColor White
    $percentage = [math]::Round($finalCheck.Installed/$finalCheck.Total*100,1)
    Write-Host "Installed: $($finalCheck.Installed) ($percentage%)" -ForegroundColor Green
    
    if ($finalCheck.Missing.Count -gt 0) {
        Write-Host "Missing: $($finalCheck.Missing.Count) - $($finalCheck.Missing -join ', ')" -ForegroundColor Red
    }
    
    if ($finalCheck.Installed -eq $finalCheck.Total) {
        Write-Host "`n*** 100% SUCCESS RATE ACHIEVED! ***" -ForegroundColor Green
        Write-Host "All 16 applications are successfully installed!" -ForegroundColor Green
    }
    else {
        Write-Host "`nNot at 100% yet. Running targeted fixes for missing apps..." -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}