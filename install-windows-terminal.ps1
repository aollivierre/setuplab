# Install Windows Terminal to achieve 100%
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Installing Windows Terminal to complete 100% installation..." -ForegroundColor Cyan

$session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop

Write-Host "`nInstalling Windows Terminal..." -ForegroundColor Yellow
$result = Invoke-Command -Session $session -ScriptBlock {
    try {
        # Check if already installed
        $existing = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
        if ($existing) {
            return "Windows Terminal is already installed (version: $($existing.Version))"
        }
        
        # Method 1: Try downloading MSIX bundle directly
        Write-Host "  Attempting direct MSIX installation..." -ForegroundColor Gray
        $msixUrl = "https://github.com/microsoft/terminal/releases/download/v1.19.10821.0/Microsoft.WindowsTerminal_1.19.10821.0_8wekyb3d8bbwe.msixbundle"
        $msixPath = "$env:TEMP\WindowsTerminal.msixbundle"
        
        try {
            Write-Host "  Downloading Windows Terminal MSIX bundle..."
            Invoke-WebRequest -Uri $msixUrl -OutFile $msixPath -UseBasicParsing
            
            Write-Host "  Installing MSIX bundle..."
            Add-AppxPackage -Path $msixPath -ErrorAction Stop
            
            Remove-Item $msixPath -Force -ErrorAction SilentlyContinue
            
            # Verify installation
            $installed = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
            if ($installed) {
                return "SUCCESS: Windows Terminal installed via MSIX (version: $($installed.Version))"
            }
        }
        catch {
            Write-Host "  MSIX installation failed: $_" -ForegroundColor Yellow
        }
        
        # Method 2: Try Windows Package Manager (winget)
        Write-Host "  Attempting installation via winget..." -ForegroundColor Gray
        $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        
        if (Test-Path $wingetPath) {
            try {
                $process = Start-Process -FilePath $wingetPath -ArgumentList "install --id Microsoft.WindowsTerminal --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    $installed = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                    if ($installed) {
                        return "SUCCESS: Windows Terminal installed via winget (version: $($installed.Version))"
                    }
                }
            }
            catch {
                Write-Host "  Winget installation failed: $_" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  Winget not available" -ForegroundColor Gray
        }
        
        # Method 3: Download from Microsoft Store indirectly
        Write-Host "  Attempting installation via Store dependencies..." -ForegroundColor Gray
        
        # First ensure dependencies
        $dependencies = @(
            "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx",
            "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
        )
        
        foreach ($depUrl in $dependencies) {
            try {
                $depFile = "$env:TEMP\$([System.IO.Path]::GetFileName($depUrl))"
                Invoke-WebRequest -Uri $depUrl -OutFile $depFile -UseBasicParsing
                Add-AppxPackage -Path $depFile -ErrorAction SilentlyContinue
                Remove-Item $depFile -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Continue even if dependency fails
            }
        }
        
        # Try alternative MSIX URLs
        $alternativeUrls = @(
            "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_Win11_1.18.10301.0_8wekyb3d8bbwe.msixbundle",
            "https://github.com/microsoft/terminal/releases/download/v1.17.11461.0/Microsoft.WindowsTerminal_1.17.11461.0_8wekyb3d8bbwe.msixbundle"
        )
        
        foreach ($url in $alternativeUrls) {
            try {
                $msixPath = "$env:TEMP\WindowsTerminal_alt.msixbundle"
                Write-Host "  Trying alternative version..."
                Invoke-WebRequest -Uri $url -OutFile $msixPath -UseBasicParsing
                Add-AppxPackage -Path $msixPath -ErrorAction Stop
                Remove-Item $msixPath -Force -ErrorAction SilentlyContinue
                
                $installed = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
                if ($installed) {
                    return "SUCCESS: Windows Terminal installed via alternative version (version: $($installed.Version))"
                }
            }
            catch {
                # Try next URL
            }
        }
        
        # Final check
        $finalCheck = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
        if ($finalCheck) {
            return "SUCCESS: Windows Terminal is now installed (version: $($finalCheck.Version))"
        }
        else {
            return "FAILED: Unable to install Windows Terminal through any method"
        }
    }
    catch {
        return "ERROR: $_"
    }
}

Write-Host "`n$result" -ForegroundColor $(if ($result -match "SUCCESS") { "Green" } else { "Red" })

# Final verification of all 16 apps
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "FINAL VERIFICATION - ALL 16 APPS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$final = Invoke-Command -Session $session -ScriptBlock {
    $apps = @{
        "7-Zip" = { Test-Path "C:\Program Files\7-Zip\7z.exe" }
        "Git" = { Test-Path "C:\Program Files\Git\bin\git.exe" }
        "VS Code" = { Test-Path "C:\Program Files\Microsoft VS Code\Code.exe" }
        "Node.js" = { Test-Path "C:\Program Files\nodejs\node.exe" }
        "GitHub Desktop" = { (Test-Path "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe") -or (Test-Path "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe") }
        "GitHub CLI" = { Test-Path "C:\Program Files\GitHub CLI\gh.exe" }
        "PowerShell 7" = { Test-Path "C:\Program Files\PowerShell\7\pwsh.exe" }
        "Chrome" = { (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") }
        "Firefox" = { Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe" }
        "ShareX" = { Test-Path "C:\Program Files\ShareX\ShareX.exe" }
        "Everything" = { Test-Path "C:\Program Files\Everything\Everything.exe" }
        "FileLocator Pro" = { Test-Path "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe" }
        "Visual C++ Redist" = { Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" }
        "Warp Terminal" = { (Test-Path "$env:LOCALAPPDATA\Programs\Warp\Warp.exe") -or (Test-Path "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe") }
        "Windows Terminal" = { Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue }
        "Claude CLI" = { (Test-Path "$env:APPDATA\npm\claude.cmd") -or (Test-Path "C:\Users\administrator\AppData\Roaming\npm\claude.cmd") }
    }
    
    $installed = 0
    $missing = @()
    
    foreach ($app in $apps.GetEnumerator()) {
        if (& $app.Value) {
            $installed++
        } else {
            $missing += $app.Key
        }
    }
    
    @{
        Installed = $installed
        Total = $apps.Count
        Missing = $missing
    }
}

foreach ($i in 1..16) {
    Write-Host -NoNewline "█" -ForegroundColor $(if ($i -le $final.Installed) { "Green" } else { "Red" })
}

$percentage = [math]::Round(($final.Installed / $final.Total) * 100, 1)
Write-Host " $($final.Installed)/$($final.Total) ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })

if ($final.Installed -eq 16) {
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "🎉 100% SUCCESS RATE ACHIEVED! 🎉" -ForegroundColor Green
    Write-Host "ALL 16 APPLICATIONS SUCCESSFULLY INSTALLED!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Host "`nStill missing: $($final.Missing -join ', ')" -ForegroundColor Red
}

Remove-PSSession -Session $session