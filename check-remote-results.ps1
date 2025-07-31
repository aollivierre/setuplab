# Check detailed installation results on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking installation results on $RemoteComputer..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        # Check all software locations
        $checks = @{
            "7-Zip" = @{
                Path = "C:\Program Files\7-Zip\7z.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip"
            }
            "Git" = @{
                Path = "C:\Program Files\Git\bin\git.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Git_is1"
            }
            "VS Code" = @{
                Path = "C:\Program Files\Microsoft VS Code\Code.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{EA457B21-F73E-494C-ACAB-524FDE069978}_is1"
            }
            "Node.js" = @{
                Path = "C:\Program Files\nodejs\node.exe"
                Registry = "HKLM:\SOFTWARE\Node.js"
            }
            "GitHub Desktop" = @{
                Path = "C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe"
                Registry = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\GitHubDesktop"
            }
            "GitHub CLI" = @{
                Path = "C:\Program Files\GitHub CLI\gh.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{284BFDBC-36FA-4E9C-820B-CC1B64DD5CF7}"
            }
            "PowerShell 7" = @{
                Path = "C:\Program Files\PowerShell\7\pwsh.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PowerShell 7-x64"
            }
            "Chrome" = @{
                Path = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe")
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
            }
            "Firefox" = @{
                Path = "C:\Program Files\Mozilla Firefox\firefox.exe"
                Registry = "HKLM:\SOFTWARE\Mozilla\Mozilla Firefox"
            }
            "ShareX" = @{
                Path = "C:\Program Files\ShareX\ShareX.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\82E6AC09-0FEF-4390-AD9F-0DD3F5561EFC_is1"
            }
            "Everything" = @{
                Path = "C:\Program Files\Everything\Everything.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Everything"
            }
            "FileLocator Pro" = @{
                Path = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
                Registry = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E428C391-48BE-427B-B949-1F670FCFACB5}"
            }
            "Warp Terminal" = @{
                Path = "C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe"
                Registry = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4A44223A-E0F2-4D23-8F06-ED11BC0EF979}"
            }
        }
        
        $results = @{}
        
        foreach ($app in $checks.GetEnumerator()) {
            $found = $false
            $details = @{
                FileExists = $false
                RegistryExists = $false
                Path = $null
            }
            
            # Check file paths
            if ($app.Value.Path -is [array]) {
                foreach ($path in $app.Value.Path) {
                    if (Test-Path $path) {
                        $details.FileExists = $true
                        $details.Path = $path
                        $found = $true
                        break
                    }
                }
            }
            else {
                if (Test-Path $app.Value.Path) {
                    $details.FileExists = $true
                    $details.Path = $app.Value.Path
                    $found = $true
                }
            }
            
            # Check registry
            if ($app.Value.Registry -and (Test-Path $app.Value.Registry)) {
                $details.RegistryExists = $true
                $found = $true
            }
            
            $results[$app.Key] = @{
                Installed = $found
                Details = $details
            }
        }
        
        # Get installation logs
        $logs = @()
        $logPath = "C:\SetupLab\Logs"
        if (Test-Path $logPath) {
            $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 2
            foreach ($logFile in $logFiles) {
                $content = Get-Content $logFile.FullName
                $errors = $content | Where-Object { $_ -match '\[Error\]' }
                $logs += @{
                    FileName = $logFile.Name
                    ErrorCount = $errors.Count
                    Errors = $errors | Select-Object -Last 5
                    TotalLines = $content.Count
                }
            }
        }
        
        # Check temp folder for failed installers
        $tempFiles = Get-ChildItem -Path $env:TEMP -Filter "*_installer.*" -ErrorAction SilentlyContinue | 
                     Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }
        
        @{
            Software = $results
            Logs = $logs
            TempFiles = $tempFiles | Select-Object Name, Length, LastWriteTime
        }
    }
    
    # Display results
    Write-Host "`nSoftware Installation Status:" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Yellow
    
    $installed = @()
    $notInstalled = @()
    
    foreach ($app in $results.Software.GetEnumerator() | Sort-Object Key) {
        $status = if ($app.Value.Installed) { 
            $installed += $app.Key
            "INSTALLED" 
        } else { 
            $notInstalled += $app.Key
            "NOT FOUND" 
        }
        
        $color = if ($app.Value.Installed) { "Green" } else { "Red" }
        Write-Host ("{0,-20} : {1}" -f $app.Key, $status) -ForegroundColor $color
        
        if ($app.Value.Details.Path) {
            Write-Host ("  Path: {0}" -f $app.Value.Details.Path) -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "Installed: $($installed.Count) apps - $($installed -join ', ')" -ForegroundColor Green
    Write-Host "Not Installed: $($notInstalled.Count) apps - $($notInstalled -join ', ')" -ForegroundColor Red
    
    # Show log information
    if ($results.Logs) {
        Write-Host "`nLog Files:" -ForegroundColor Yellow
        foreach ($log in $results.Logs) {
            Write-Host "  $($log.FileName) - $($log.TotalLines) lines, $($log.ErrorCount) errors" -ForegroundColor Gray
            if ($log.Errors) {
                Write-Host "  Recent errors:" -ForegroundColor Red
                $log.Errors | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
            }
        }
    }
    
    # Show temp files
    if ($results.TempFiles) {
        Write-Host "`nLeftover installer files in temp:" -ForegroundColor Yellow
        $results.TempFiles | ForEach-Object {
            Write-Host "  $($_.Name) - $([math]::Round($_.Length/1MB,2))MB - $($_.LastWriteTime)" -ForegroundColor Gray
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}