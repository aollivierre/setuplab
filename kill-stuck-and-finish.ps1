# Kill stuck Warp installer and finish remaining installations
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Cleaning up stuck installer and finishing remaining apps..." -ForegroundColor Yellow

$session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop

# Kill stuck Warp installer
Write-Host "`nKilling stuck Warp installer..." -ForegroundColor Red
Invoke-Command -Session $session -ScriptBlock {
    Get-Process -Name "*Warp*", "*setup*", "*installer*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Try Warp again with correct arguments
Write-Host "`n[1/2] Installing Warp Terminal (with correct args)..." -ForegroundColor Yellow
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
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $installer)
        
        Write-Host "  Installing Warp Terminal with /VERYSILENT..."
        $process = Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES" -Wait -PassThru
        
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        
        # Check multiple possible locations
        $installed = $false
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Programs\Warp\Warp.exe",
            "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe",
            "$env:ProgramFiles\Warp\Warp.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $installed = $true
                Write-Host "  Warp Terminal found at: $path" -ForegroundColor Green
                break
            }
        }
        
        if ($installed) {
            Write-Host "  Warp Terminal installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "  Warp Terminal installation completed, but exe not found" -ForegroundColor Yellow
            Write-Host "  Exit code: $($process.ExitCode)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Claude CLI
Write-Host "`n[2/2] Installing Claude CLI..." -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    try {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        if (Test-Path $claudePath) {
            Write-Host "  Claude CLI is already installed" -ForegroundColor Green
            return
        }
        
        # Update PATH first
        $nodePath = "C:\Program Files\nodejs"
        $npmPath = "$nodePath\npm.cmd"
        
        if (-not (Test-Path $npmPath)) {
            Write-Host "  npm not found - cannot install Claude CLI" -ForegroundColor Red
            return
        }
        
        Write-Host "  Installing Claude CLI via npm..."
        
        # Set up environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + $nodePath
        
        # Run npm install with full path
        $arguments = "install -g @anthropic-ai/claude-code"
        $npmProcess = Start-Process -FilePath $npmPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        # Check if successful
        if ($npmProcess.ExitCode -eq 0) {
            # Wait for files to be created
            Start-Sleep -Seconds 3
            
            # Check multiple locations
            $claudeInstalled = $false
            $possiblePaths = @(
                "$env:APPDATA\npm\claude.cmd",
                "C:\Users\administrator\AppData\Roaming\npm\claude.cmd",
                "$nodePath\claude.cmd"
            )
            
            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $claudeInstalled = $true
                    Write-Host "  Claude CLI found at: $path" -ForegroundColor Green
                    break
                }
            }
            
            if ($claudeInstalled) {
                Write-Host "  Claude CLI installed successfully!" -ForegroundColor Green
            } else {
                Write-Host "  Claude CLI installation completed but cmd not found" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  npm install failed with exit code: $($npmProcess.ExitCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Final comprehensive check
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "FINAL COMPREHENSIVE CHECK" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$finalResults = Invoke-Command -Session $session -ScriptBlock {
    # Detailed checks for all 16 apps
    $detailedChecks = @{
        "7-Zip" = @{
            Paths = @("C:\Program Files\7-Zip\7z.exe")
            Type = "File"
        }
        "Git" = @{
            Paths = @("C:\Program Files\Git\bin\git.exe")
            Type = "File"
        }
        "VS Code" = @{
            Paths = @("C:\Program Files\Microsoft VS Code\Code.exe")
            Type = "File"
        }
        "Node.js" = @{
            Paths = @("C:\Program Files\nodejs\node.exe")
            Type = "File"
        }
        "GitHub Desktop" = @{
            Paths = @(
                "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe",
                "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe"
            )
            Type = "File"
        }
        "GitHub CLI" = @{
            Paths = @("C:\Program Files\GitHub CLI\gh.exe")
            Type = "File"
        }
        "PowerShell 7" = @{
            Paths = @("C:\Program Files\PowerShell\7\pwsh.exe")
            Type = "File"
        }
        "Chrome" = @{
            Paths = @(
                "C:\Program Files\Google\Chrome\Application\chrome.exe",
                "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            )
            Type = "File"
        }
        "Firefox" = @{
            Paths = @("C:\Program Files\Mozilla Firefox\firefox.exe")
            Type = "File"
        }
        "ShareX" = @{
            Paths = @("C:\Program Files\ShareX\ShareX.exe")
            Type = "File"
        }
        "Everything" = @{
            Paths = @("C:\Program Files\Everything\Everything.exe")
            Type = "File"
        }
        "FileLocator Pro" = @{
            Paths = @("C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe")
            Type = "File"
        }
        "Visual C++ Redist" = @{
            Paths = @("HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64")
            Type = "Registry"
        }
        "Warp Terminal" = @{
            Paths = @(
                "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe",
                "$env:LOCALAPPDATA\Programs\Warp\Warp.exe"
            )
            Type = "File"
        }
        "Windows Terminal" = @{
            Type = "AppX"
        }
        "Claude CLI" = @{
            Paths = @(
                "C:\Users\administrator\AppData\Roaming\npm\claude.cmd",
                "$env:APPDATA\npm\claude.cmd"
            )
            Type = "File"
        }
    }
    
    $results = @()
    $installedCount = 0
    
    foreach ($app in $detailedChecks.GetEnumerator()) {
        $found = $false
        $foundPath = "Not Found"
        
        switch ($app.Value.Type) {
            "File" {
                foreach ($path in $app.Value.Paths) {
                    $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
                    if (Test-Path $expandedPath) {
                        $found = $true
                        $foundPath = $expandedPath
                        break
                    }
                }
            }
            "Registry" {
                if (Test-Path $app.Value.Paths[0]) {
                    $found = $true
                    $foundPath = "Registry Key"
                }
            }
            "AppX" {
                $appx = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                if ($appx) {
                    $found = $true
                    $foundPath = "Windows Store App"
                }
            }
        }
        
        if ($found) { $installedCount++ }
        
        $results += [PSCustomObject]@{
            Name = $app.Key
            Installed = $found
            Path = $foundPath
        }
    }
    
    @{
        Results = $results | Sort-Object Name
        InstalledCount = $installedCount
        TotalCount = $detailedChecks.Count
        MissingApps = ($results | Where-Object { -not $_.Installed }).Name
    }
}

# Display results
foreach ($app in $finalResults.Results) {
    $status = if ($app.Installed) { "INSTALLED" } else { "MISSING" }
    $color = if ($app.Installed) { "Green" } else { "Red" }
    
    if ($app.Installed -and $app.Path -ne "Registry Key" -and $app.Path -ne "Windows Store App") {
        Write-Host ("{0,-20} : {1,-12} [{2}]" -f $app.Name, $status, $app.Path) -ForegroundColor $color
    } else {
        Write-Host ("{0,-20} : {1}" -f $app.Name, $status) -ForegroundColor $color
    }
}

$percentage = [math]::Round(($finalResults.InstalledCount / $finalResults.TotalCount) * 100, 1)
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "FINAL SCORE: $($finalResults.InstalledCount)/$($finalResults.TotalCount) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })

if ($finalResults.InstalledCount -eq $finalResults.TotalCount) {
    Write-Host "`n*** 100% SUCCESS RATE ACHIEVED! ***" -ForegroundColor Green
    Write-Host "ALL 16 APPLICATIONS SUCCESSFULLY INSTALLED!" -ForegroundColor Green
} else {
    Write-Host "`nMissing: $($finalResults.MissingApps -join ', ')" -ForegroundColor Red
}

Remove-PSSession -Session $session