# Test SetupLab installation on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Connecting to $RemoteComputer..." -ForegroundColor Yellow

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected successfully" -ForegroundColor Green
    
    # Copy updated files to remote machine
    Write-Host "`nCopying updated files to remote machine..." -ForegroundColor Yellow
    
    $remotePath = "C:\SetupLab"
    
    # Create remote directory
    Invoke-Command -Session $session -ScriptBlock {
        param($path)
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    } -ArgumentList $remotePath
    
    # Files to copy
    $filesToCopy = @(
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "main.ps1",
        "software-config.json",
        "Download-Sysinternals.ps1",
        "Configure-WindowsTerminal.ps1",
        "install-claude-cli.ps1",
        "Set-DNSServers.ps1",
        "Rename-Computer.ps1",
        "Join-Domain.ps1"
    )
    
    # Copy each file
    foreach ($file in $filesToCopy) {
        $sourcePath = Join-Path $PSScriptRoot $file
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $remotePath -ToSession $session -Force
            Write-Host "  Copied: $file" -ForegroundColor Gray
        }
    }
    
    # Copy subdirectories
    $subDirs = @("DarkTheme", "Terminal")
    foreach ($dir in $subDirs) {
        $sourcePath = Join-Path $PSScriptRoot $dir
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $remotePath -ToSession $session -Recurse -Force
            Write-Host "  Copied directory: $dir" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nStarting SetupLab installation on remote machine..." -ForegroundColor Yellow
    
    # Run the installation remotely
    $remoteScript = {
        param($setupPath)
        
        # Set execution policy
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Change to setup directory
        Set-Location $setupPath
        
        # Run main.ps1 with enhanced logging
        try {
            # Run main script directly - it will handle module imports
            & (Join-Path $setupPath "main.ps1") -SkipValidation
        }
        catch {
            Write-Error "Installation failed: $_"
            Write-Error $_.Exception.StackTrace
        }
    }
    
    # Execute installation
    Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList $remotePath
    
    # Get logs from remote machine
    Write-Host "`nRetrieving logs from remote machine..." -ForegroundColor Yellow
    
    $remoteLogs = Invoke-Command -Session $session -ScriptBlock {
        $logPath = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem -Path $logPath -Filter "*.log" | 
                         Sort-Object LastWriteTime -Descending | 
                         Select-Object -First 1
            if ($latestLog) {
                Get-Content $latestLog.FullName -Tail 100
            }
        }
    }
    
    if ($remoteLogs) {
        Write-Host "`nLatest log entries:" -ForegroundColor Cyan
        $remoteLogs | ForEach-Object { Write-Host $_ }
    }
    
    # Check installation results
    Write-Host "`nChecking installation results..." -ForegroundColor Yellow
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $installed = @()
        $failed = @()
        
        # Check specific software
        $software = @(
            @{Name="7-Zip"; Path="C:\Program Files\7-Zip\7z.exe"},
            @{Name="Git"; Path="C:\Program Files\Git\bin\git.exe"},
            @{Name="VS Code"; Path="C:\Program Files\Microsoft VS Code\Code.exe"},
            @{Name="PowerShell 7"; Path="C:\Program Files\PowerShell\7\pwsh.exe"},
            @{Name="GitHub CLI"; Path="C:\Program Files\GitHub CLI\gh.exe"},
            @{Name="Node.js"; Path="C:\Program Files\nodejs\node.exe"}
        )
        
        foreach ($app in $software) {
            if (Test-Path $app.Path) {
                $installed += $app.Name
            } else {
                $failed += $app.Name
            }
        }
        
        @{
            Installed = $installed
            Failed = $failed
        }
    }
    
    Write-Host "`nInstallation Results:" -ForegroundColor Cyan
    Write-Host "Installed: $($results.Installed -join ', ')" -ForegroundColor Green
    if ($results.Failed.Count -gt 0) {
        Write-Host "Failed: $($results.Failed -join ', ')" -ForegroundColor Red
    }
    
    # Cleanup
    Remove-PSSession -Session $session
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
}