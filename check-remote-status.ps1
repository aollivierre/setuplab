# Check remote installation status
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`nChecking installation status..." -ForegroundColor Cyan
    
    # Check log file
    $logContent = Invoke-Command -Session $session -ScriptBlock {
        $logPath = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLog) {
                $tailContent = Get-Content $latestLog.FullName | Select-Object -Last 50
                return @{
                    LogFile = $latestLog.Name
                    Content = $tailContent -join "`n"
                }
            }
        }
        return $null
    }
    
    if ($logContent) {
        Write-Host "`nLatest log: $($logContent.LogFile)" -ForegroundColor Yellow
        Write-Host "Last 50 lines:" -ForegroundColor Yellow
        Write-Host $logContent.Content
    }
    
    # Check current installations
    Write-Host "`n`nCurrent Installation Status:" -ForegroundColor Cyan
    $status = Invoke-Command -Session $session -ScriptBlock {
        $apps = @{
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
            "VC++ Redist" = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            "Warp" = "$env:LOCALAPPDATA\Programs\Warp\Warp.exe"
            "Windows Terminal" = $null
            "Claude CLI" = "$env:APPDATA\npm\claude.cmd"
        }
        
        $installed = @()
        $missing = @()
        
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
            
            if ($found) {
                $installed += $app.Key
            } else {
                $missing += $app.Key
            }
        }
        
        @{
            Installed = $installed | Sort-Object
            Missing = $missing | Sort-Object
            Count = $installed.Count
            Total = $apps.Count
        }
    }
    
    Write-Host "`nInstalled ($($status.Count)/$($status.Total)):" -ForegroundColor Green
    $status.Installed | ForEach-Object { Write-Host "  [OK] $_" -ForegroundColor Green }
    
    if ($status.Missing.Count -gt 0) {
        Write-Host "`nMissing:" -ForegroundColor Red
        $status.Missing | ForEach-Object { Write-Host "  [X] $_" -ForegroundColor Red }
    }
    
    $percentage = [math]::Round(($status.Count / $status.Total) * 100, 1)
    Write-Host "`nProgress: $percentage%" -ForegroundColor Yellow
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}