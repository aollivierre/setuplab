# Test web launcher end-to-end on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n##############################################################" -ForegroundColor Cyan
Write-Host "#          TESTING WEB LAUNCHER ON REMOTE MACHINE            #" -ForegroundColor Cyan
Write-Host "##############################################################" -ForegroundColor Cyan
Write-Host "# Remote: $RemoteComputer" -ForegroundColor Yellow
Write-Host "# Testing: iex (irm ...) with fixed web launcher" -ForegroundColor Yellow
Write-Host "##############################################################`n" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "[OK] Connected to remote machine" -ForegroundColor Green
    
    # First, clean up any previous attempts
    Write-Host "`n[STEP 1] Cleaning up previous attempts..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Kill any stuck installers
        Get-Process -Name "*setup*", "*install*", "*msiexec*" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -ne "setuplab01" } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Clean temp folders
        Get-ChildItem "$env:TEMP\SetupLab_*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        
        # Clear any error logs
        if (Test-Path "C:\code\logs.txt") {
            Remove-Item "C:\code\logs.txt" -Force
        }
    }
    Write-Host "[OK] Cleanup completed" -ForegroundColor Green
    
    # Test the web launcher
    Write-Host "`n[STEP 2] Testing web launcher..." -ForegroundColor Yellow
    Write-Host "Executing: iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')" -ForegroundColor Gray
    
    $startTime = Get-Date
    
    # Run the web launcher and capture output
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Capture both output and errors
            $output = @()
            $errors = @()
            
            # Run the web launcher
            $scriptOutput = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
            
            foreach ($item in $scriptOutput) {
                if ($item -is [System.Management.Automation.ErrorRecord]) {
                    $errors += $item.ToString()
                } else {
                    $output += $item.ToString()
                }
            }
            
            @{
                Success = $errors.Count -eq 0
                Output = $output
                Errors = $errors
                TempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -ErrorAction SilentlyContinue | Select-Object Name
            }
        }
        catch {
            @{
                Success = $false
                Output = @()
                Errors = @($_.Exception.Message, $_.Exception.StackTrace)
                TempFolders = @()
            }
        }
    }
    
    $duration = (Get-Date) - $startTime
    
    # Display results
    Write-Host "`n[STEP 3] Results:" -ForegroundColor Yellow
    
    if ($result.Success) {
        Write-Host "[OK] Web launcher executed successfully!" -ForegroundColor Green
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
        
        if ($result.Output.Count -gt 0) {
            Write-Host "`nOutput (last 50 lines):" -ForegroundColor Gray
            $result.Output | Select-Object -Last 50 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    }
    else {
        Write-Host "[ERROR] Web launcher failed!" -ForegroundColor Red
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
        
        if ($result.Errors.Count -gt 0) {
            Write-Host "`nErrors:" -ForegroundColor Red
            $result.Errors | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Red
            }
        }
        
        if ($result.Output.Count -gt 0) {
            Write-Host "`nOutput (last 30 lines):" -ForegroundColor Gray
            $result.Output | Select-Object -Last 30 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    }
    
    # Check installation results
    Write-Host "`n[STEP 4] Checking installation results..." -ForegroundColor Yellow
    
    $installed = Invoke-Command -Session $session -ScriptBlock {
        $count = 0
        $apps = @{
            '7-Zip' = 'C:\Program Files\7-Zip\7z.exe'
            'Git' = 'C:\Program Files\Git\bin\git.exe'
            'VS Code' = 'C:\Program Files\Microsoft VS Code\Code.exe'
            'Node.js' = 'C:\Program Files\nodejs\node.exe'
            'GitHub CLI' = 'C:\Program Files\GitHub CLI\gh.exe'
            'PowerShell 7' = 'C:\Program Files\PowerShell\7\pwsh.exe'
            'Chrome' = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
            'Firefox' = 'C:\Program Files\Mozilla Firefox\firefox.exe'
            'ShareX' = 'C:\Program Files\ShareX\ShareX.exe'
            'Everything' = 'C:\Program Files\Everything\Everything.exe'
            'FileLocator' = 'C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe'
            'VC++ Redist' = 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
            'Warp' = 'C:\Users\administrator\AppData\Local\Programs\Warp\Warp.exe'
            'Claude CLI' = 'C:\Users\administrator\AppData\Roaming\npm\claude.cmd'
            'GitHub Desktop' = 'C:\Users\administrator\AppData\Local\GitHubDesktop\GitHubDesktop.exe'
            'Windows Terminal' = 'C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*'
        }
        
        foreach ($app in $apps.GetEnumerator()) {
            if ($app.Value -match '^HKLM:') {
                if (Test-Path $app.Value) { $count++ }
            }
            elseif ($app.Value -match '\*$') {
                if (Test-Path $app.Value) { $count++ }
            }
            else {
                if (Test-Path $app.Value) { $count++ }
            }
        }
        
        return $count
    }
    
    Write-Host "Applications installed: $installed/16" -ForegroundColor $(if ($installed -eq 16) { 'Green' } elseif ($installed -ge 14) { 'Yellow' } else { 'Red' })
    
    Write-Host "`n##############################################################" -ForegroundColor Cyan
    Write-Host "# TEST COMPLETE" -ForegroundColor Cyan
    Write-Host "##############################################################" -ForegroundColor Cyan
    
    Remove-PSSession $session
}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }
}