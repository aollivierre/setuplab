# Final test to identify the root cause
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Running final Claude CLI fix test on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Check if Claude CLI is already installed
    $initialCheck = Invoke-Command -Session $session -ScriptBlock {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        @{
            Exists = Test-Path $claudePath
            Version = if (Test-Path $claudePath) { cmd /c "`"$claudePath`" --version 2>&1" } else { "Not installed" }
        }
    }
    
    Write-Host "Initial state - Claude CLI exists: $($initialCheck.Exists), Version: $($initialCheck.Version)" -ForegroundColor Cyan
    
    if ($initialCheck.Exists) {
        Write-Host "Claude CLI is already installed! The previous test must have succeeded." -ForegroundColor Green
        Write-Host "This means the error in SetupLab logs might be misleading or from a different issue." -ForegroundColor Yellow
        
        # Let's run the web launcher again to see what happens
        Write-Host "`nRunning web launcher again to check behavior with Claude CLI already installed..." -ForegroundColor Cyan
        
        $result = Invoke-Command -Session $session -ScriptBlock {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Capture output to a file
            $logFile = "$env:TEMP\setuplab-test-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            
            Start-Transcript -Path $logFile -Force
            
            try {
                iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
            } finally {
                Stop-Transcript
            }
            
            # Extract Claude CLI related entries
            $logContent = Get-Content $logFile -Raw
            $claudeEntries = $logContent -split "`n" | Where-Object { $_ -match "Claude|install-claude-cli" }
            
            @{
                Success = $true
                ClaudeEntries = $claudeEntries -join "`n"
            }
        }
        
        Write-Host "`nClaude CLI related log entries:" -ForegroundColor Yellow
        Write-Host $result.ClaudeEntries
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}