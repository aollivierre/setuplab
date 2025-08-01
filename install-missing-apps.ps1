# Install missing apps on remote machine with enhanced error handling
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Installing missing applications on $RemoteComputer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # First, check what's already installed
    Write-Host "`nChecking current installation status..." -ForegroundColor Yellow
    
    $currentStatus = Invoke-Command -Session $session -ScriptBlock {
        $installed = @()
        $missing = @()
        
        $checks = @{
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
            "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "Visual C++ Redistributables" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp Terminal" = "C:\Users\$env:USERNAME\AppData\Local\Programs\Warp\Warp.exe"
            "Windows Terminal" = "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*"
            "Claude CLI" = "C:\Users\$env:USERNAME\AppData\Roaming\npm\claude.cmd"
        }
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            if ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    if (Test-Path $path) {
                        $found = $true
                        break
                    }
                }
            }
            elseif ($app.Value -match "^HKLM:") {
                if (Test-Path $app.Value) {
                    $found = $true
                }
            }
            else {
                if (Test-Path $app.Value) {
                    $found = $true
                }
            }
            
            if ($found) {
                $installed += $app.Key
            } else {
                $missing += $app.Key
            }
        }
        
        @{
            Installed = $installed
            Missing = $missing
        }
    }
    
    Write-Host "Already installed: $($currentStatus.Installed -join ', ')" -ForegroundColor Green
    Write-Host "Missing: $($currentStatus.Missing -join ', ')" -ForegroundColor Red
    
    if ($currentStatus.Missing.Count -eq 0) {
        Write-Host "`nAll applications are already installed!" -ForegroundColor Green
        Remove-PSSession -Session $session
        return
    }
    
    # Copy the installation scripts
    Write-Host "`nCopying installation scripts..." -ForegroundColor Yellow
    
    $remotePath = "C:\SetupLab"
    Copy-Item -Path (Join-Path $PSScriptRoot "SetupLabCore.psm1") -Destination $remotePath -ToSession $session -Force
    Copy-Item -Path (Join-Path $PSScriptRoot "SetupLabLogging.psm1") -Destination $remotePath -ToSession $session -Force
    Copy-Item -Path (Join-Path $PSScriptRoot "software-config.json") -Destination $remotePath -ToSession $session -Force
    Copy-Item -Path (Join-Path $PSScriptRoot "install-claude-cli.ps1") -Destination $remotePath -ToSession $session -Force
    
    # Install each missing app individually
    foreach ($app in $currentStatus.Missing) {
        Write-Host "`nInstalling $app..." -ForegroundColor Yellow
        
        $result = Invoke-Command -Session $session -ScriptBlock {
            param($appName, $setupPath)
            
            Set-Location $setupPath
            Import-Module (Join-Path $setupPath "SetupLabCore.psm1") -Force
            Import-Module (Join-Path $setupPath "SetupLabLogging.psm1") -Force
            
            # Load configuration
            $configPath = Join-Path $setupPath "software-config.json"
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            
            # Find the app configuration
            $appConfig = $config.software | Where-Object { $_.name -eq $appName }
            
            if (-not $appConfig) {
                return @{ Success = $false; Error = "Configuration not found for $appName" }
            }
            
            try {
                # Special handling for specific apps
                switch ($appName) {
                    "Node.js" {
                        # Remove ETW components that cause issues
                        $appConfig.installArguments = @("/quiet", "/norestart", "ADDLOCAL=NodeRuntime,npm", "REMOVE=NodeETWSupport,NodePerfCtrSupport")
                    }
                    "Claude CLI" {
                        # Ensure npm is in PATH first
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                        
                        # Check if npm exists
                        $npmPath = Get-Command npm -ErrorAction SilentlyContinue
                        if (-not $npmPath) {
                            return @{ Success = $false; Error = "npm not found in PATH" }
                        }
                        
                        # Run the custom install script
                        $scriptPath = Join-Path $setupPath "install-claude-cli.ps1"
                        if (Test-Path $scriptPath) {
                            & $scriptPath
                            return @{ Success = $true; Message = "Claude CLI installation script executed" }
                        }
                        else {
                            return @{ Success = $false; Error = "install-claude-cli.ps1 not found" }
                        }
                    }
                    "Windows Terminal" {
                        # Check if already installed via Store/MSIX
                        $wtInstalled = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                        if ($wtInstalled) {
                            return @{ Success = $true; Message = "Windows Terminal already installed via Store" }
                        }
                    }
                }
                
                # Download installer
                if ($appConfig.downloadUrl) {
                    $installerPath = Join-Path $env:TEMP "$($appConfig.name)_installer$($appConfig.installerExtension)"
                    
                    Write-Host "Downloading from: $($appConfig.downloadUrl)"
                    Start-SetupDownload -Url $appConfig.downloadUrl -Destination $installerPath
                    
                    # Install
                    Write-Host "Installing $appName..."
                    Invoke-SetupInstaller -InstallerPath $installerPath -Arguments $appConfig.installArguments -InstallType $appConfig.installType
                    
                    # Cleanup
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                }
                
                # Verify installation
                Start-Sleep -Seconds 3
                
                $verifyPath = switch ($appName) {
                    "Node.js" { "C:\Program Files\nodejs\node.exe" }
                    "Chrome" { @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") }
                    "Firefox" { "C:\Program Files\Mozilla Firefox\firefox.exe" }
                    "ShareX" { "C:\Program Files\ShareX\ShareX.exe" }
                    "Everything" { "C:\Program Files\Everything\Everything.exe" }
                    "FileLocator Pro" { "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe" }
                    "Warp Terminal" { "C:\Users\$env:USERNAME\AppData\Local\Programs\Warp\Warp.exe" }
                    "Claude CLI" { "C:\Users\$env:USERNAME\AppData\Roaming\npm\claude.cmd" }
                    default { $null }
                }
                
                $installed = $false
                if ($verifyPath) {
                    if ($verifyPath -is [array]) {
                        foreach ($path in $verifyPath) {
                            if (Test-Path $path) {
                                $installed = $true
                                break
                            }
                        }
                    }
                    else {
                        $installed = Test-Path $verifyPath
                    }
                }
                
                if ($appName -eq "Visual C++ Redistributables") {
                    $installed = Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
                }
                
                return @{ 
                    Success = $installed
                    Message = if ($installed) { "$appName installed successfully" } else { "$appName installation verification failed" }
                }
            }
            catch {
                return @{ Success = $false; Error = $_.Exception.Message }
            }
        } -ArgumentList $app, $remotePath
        
        if ($result.Success) {
            Write-Host "  SUCCESS: $($result.Message)" -ForegroundColor Green
        }
        else {
            Write-Host "  FAILED: $($result.Error)" -ForegroundColor Red
            
            # Try alternative approach for specific apps
            if ($app -eq "Node.js") {
                Write-Host "  Trying alternative Node.js installation..." -ForegroundColor Yellow
                
                $altResult = Invoke-Command -Session $session -ScriptBlock {
                    try {
                        # Download Node.js installer
                        $url = "https://nodejs.org/dist/v20.18.1/node-v20.18.1-x64.msi"
                        $installer = "$env:TEMP\nodejs.msi"
                        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
                        
                        # Install with minimal features
                        $arguments = @(
                            "/i",
                            "`"$installer`"",
                            "/quiet",
                            "/norestart",
                            "ADDLOCAL=NodeRuntime,npm"
                        )
                        
                        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
                        
                        Remove-Item $installer -Force -ErrorAction SilentlyContinue
                        
                        $success = (Test-Path "C:\Program Files\nodejs\node.exe")
                        return @{ Success = $success; ExitCode = $process.ExitCode }
                    }
                    catch {
                        return @{ Success = $false; Error = $_.Exception.Message }
                    }
                }
                
                if ($altResult.Success) {
                    Write-Host "  SUCCESS: Node.js installed with alternative method" -ForegroundColor Green
                }
                else {
                    Write-Host "  Alternative method also failed: $($altResult.Error)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Final verification
    Write-Host "`nFinal verification..." -ForegroundColor Yellow
    
    $finalStatus = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        $checks = @{
            "7-Zip" = "C:\Program Files\7-Zip\7z.exe"
            "Git" = "C:\Program Files\Git\bin\git.exe"
            "VS Code" = "C:\Program Files\Microsoft VS Code\Code.exe"
            "Node.js" = "C:\Program Files\nodejs\node.exe"
            "GitHub Desktop" = "C:\Users\$env:USERNAME\AppData\Local\GitHubDesktop\GitHubDesktop.exe"
            "GitHub CLI" = "C:\Program Files\GitHub CLI\gh.exe"
            "PowerShell 7" = "C:\Program Files\PowerShell\7\pwsh.exe"
            "Chrome" = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
            "Firefox" = "C:\Program Files\Mozilla Firefox\firefox.exe"
            "ShareX" = "C:\Program Files\ShareX\ShareX.exe"
            "Everything" = "C:\Program Files\Everything\Everything.exe"
            "FileLocator Pro" = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            "Visual C++ Redistributables" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp Terminal" = "C:\Users\$env:USERNAME\AppData\Local\Programs\Warp\Warp.exe"
            "Windows Terminal" = "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*"
            "Claude CLI" = "C:\Users\$env:USERNAME\AppData\Roaming\npm\claude.cmd"
        }
        
        $installed = 0
        $missing = @()
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            if ($app.Value -is [array]) {
                foreach ($path in $app.Value) {
                    if (Test-Path $path) {
                        $found = $true
                        break
                    }
                }
            }
            elseif ($app.Value -match "^HKLM:") {
                if (Test-Path $app.Value) {
                    $found = $true
                }
            }
            elseif ($app.Value -contains "*") {
                if (Get-ChildItem $app.Value -ErrorAction SilentlyContinue) {
                    $found = $true
                }
            }
            else {
                if (Test-Path $app.Value) {
                    $found = $true
                }
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
            Total = $checks.Count
        }
    }
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "FINAL RESULTS:" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    foreach ($app in $finalStatus.Results.GetEnumerator() | Sort-Object Key) {
        $status = if ($app.Value) { "INSTALLED" } else { "MISSING" }
        $color = if ($app.Value) { "Green" } else { "Red" }
        Write-Host ("{0,-30} : {1}" -f $app.Key, $status) -ForegroundColor $color
    }
    
    Write-Host "`nSUMMARY:" -ForegroundColor Yellow
    Write-Host "Total: $($finalStatus.Total)" -ForegroundColor White
    Write-Host "Installed: $($finalStatus.Installed) ($([math]::Round($finalStatus.Installed/$finalStatus.Total*100,1))%)" -ForegroundColor Green
    
    if ($finalStatus.Missing.Count -gt 0) {
        Write-Host "Missing: $($finalStatus.Missing.Count) - $($finalStatus.Missing -join ', ')" -ForegroundColor Red
    }
    
    if ($finalStatus.Installed -eq $finalStatus.Total) {
        Write-Host "`n[CELEBRATE] 100% SUCCESS RATE ACHIEVED! [CELEBRATE]" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}