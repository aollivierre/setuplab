# Final test of Claude installation via web launcher
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Final test of Claude installation on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. Current Claude status:" -ForegroundColor Cyan
    $status = Invoke-Command -Session $session -ScriptBlock {
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        @{
            Exists = Test-Path $claudePath
            Version = if (Test-Path $claudePath) { cmd /c "`"$claudePath`" --version 2>&1" } else { "Not installed" }
        }
    }
    Write-Host "Claude exists: $($status.Exists), Version: $($status.Version)" -ForegroundColor Gray
    
    Write-Host "`n2. Running web launcher (should skip Claude if already installed)..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Run web launcher and capture Claude-related output
        $output = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
        
        # Extract Claude-related lines
        $claudeLines = $output | Where-Object { $_ -match "Claude|install-claude" } | Out-String
        
        # Check final status
        $finalClaudePath = "$env:APPDATA\npm\claude.cmd"
        $finalStatus = @{
            Exists = Test-Path $finalClaudePath
            Version = if (Test-Path $finalClaudePath) { cmd /c "`"$finalClaudePath`" --version 2>&1" } else { "Not installed" }
        }
        
        @{
            ClaudeOutput = $claudeLines
            FinalStatus = $finalStatus
        }
    }
    
    Write-Host "`nClaude-related output from web launcher:" -ForegroundColor Yellow
    Write-Host $result.ClaudeOutput
    
    Write-Host "`n3. Final Claude status:" -ForegroundColor Cyan
    Write-Host "Claude exists: $($result.FinalStatus.Exists)" -ForegroundColor $(if($result.FinalStatus.Exists){'Green'}else{'Red'})
    Write-Host "Version: $($result.FinalStatus.Version)" -ForegroundColor Gray
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}