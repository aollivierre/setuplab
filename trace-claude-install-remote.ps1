# Trace Claude CLI installation issue
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Tracing Claude CLI installation on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $trace = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        # Find the exact error from SetupLab
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort-Object LastWriteTime -Descending
        if ($tempFolders) {
            $latestTemp = $tempFolders[0]
            $mainLog = Join-Path $latestTemp.FullName "Logs\SetupLab_$(Get-Date -Format 'yyyyMMdd').log"
            
            if (Test-Path $mainLog) {
                # Get Claude CLI installation section
                $logContent = Get-Content $mainLog -Raw
                $claudeSection = $logContent | Select-String -Pattern "\[14/16\] Installing: Claude CLI" -Context 0,20
                $results.ClaudeInstallLog = $claudeSection.Matches | ForEach-Object { 
                    $_.Context.PreContext + $_.Line + $_.Context.PostContext 
                }
            }
        }
        
        # Check what happens when we run the script directly
        $claudeScriptPath = Join-Path $latestTemp.FullName "install-claude-cli.ps1"
        if (Test-Path $claudeScriptPath) {
            try {
                # Set execution policy
                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                
                # Try to run the script
                $output = & $claudeScriptPath 2>&1 | Out-String
                $results.DirectRunOutput = $output
            }
            catch {
                $results.DirectRunError = $_.Exception.Message
            }
        }
        
        # Check the actual npm location
        $npmLocations = @(
            "C:\Program Files\nodejs\npm.cmd",
            "C:\Program Files\nodejs\npm",
            "$env:APPDATA\npm\npm.cmd"
        )
        
        foreach ($npm in $npmLocations) {
            if (Test-Path $npm) {
                $results.NpmFound = $npm
                break
            }
        }
        
        return $results
    }
    
    if ($trace.ClaudeInstallLog) {
        Write-Host "`nClaude CLI Installation Log:" -ForegroundColor Cyan
        $trace.ClaudeInstallLog | ForEach-Object { Write-Host $_ }
    }
    
    if ($trace.DirectRunOutput) {
        Write-Host "`n`nDirect Script Run Output:" -ForegroundColor Yellow
        Write-Host $trace.DirectRunOutput
    }
    
    if ($trace.DirectRunError) {
        Write-Host "`n`nDirect Script Run Error:" -ForegroundColor Red
        Write-Host $trace.DirectRunError
    }
    
    if ($trace.NpmFound) {
        Write-Host "`n`nNPM found at: $($trace.NpmFound)" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}