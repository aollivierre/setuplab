# Test web launcher with debugging on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Connecting to $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "Running web launcher with enhanced debugging..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Set execution policy for this session
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Run the web launcher
        Write-Host "Starting SetupLab Web Launcher..." -ForegroundColor Green
        iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
        
        # Return result
        "Completed"
    }
    
    Write-Host "Result: $result" -ForegroundColor Green
    
    # Check Claude CLI status after installation
    Write-Host "`nChecking Claude CLI installation..." -ForegroundColor Yellow
    $claudeCheck = Invoke-Command -Session $session -ScriptBlock {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        $exists = Test-Path $claudePath
        $version = if ($exists) { 
            try {
                cmd /c "`"$claudePath`" --version 2>&1"
            } catch {
                "Error: $_"
            }
        } else { 
            "Not found" 
        }
        
        # Also check the log files
        $logDir = "C:\ProgramData\SetupLab\Logs"
        $latestLog = if (Test-Path $logDir) {
            Get-ChildItem "$logDir\*.txt" | Sort LastWriteTime -Desc | Select -First 1 | Get-Content -Tail 50
        } else {
            "No SetupLab logs found"
        }
        
        @{
            Exists = $exists
            Version = $version
            LatestLog = $latestLog
        }
    }
    
    Write-Host "Claude CLI exists: $($claudeCheck.Exists)" -ForegroundColor $(if($claudeCheck.Exists){'Green'}else{'Red'})
    Write-Host "Version: $($claudeCheck.Version)" -ForegroundColor Cyan
    
    if ($claudeCheck.LatestLog -ne "No SetupLab logs found") {
        Write-Host "`nLatest SetupLab log entries:" -ForegroundColor Yellow
        Write-Host $claudeCheck.LatestLog
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}