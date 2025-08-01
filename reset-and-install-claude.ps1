# Reset and properly install Claude
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Resetting and installing Claude on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Set execution policy
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        Write-Host "`n1. Checking current state..." -ForegroundColor Cyan
        $claudeCmd = "$env:APPDATA\npm\claude.cmd"
        $claudeExists = Test-Path $claudeCmd
        Write-Host "Claude.cmd exists: $claudeExists at $claudeCmd" -ForegroundColor Gray
        
        # Check npm
        Write-Host "`n2. Checking npm..." -ForegroundColor Cyan
        $npmVersion = cmd /c "npm --version 2>&1"
        Write-Host "NPM version: $npmVersion" -ForegroundColor Gray
        
        # List global packages
        Write-Host "`n3. Global NPM packages:" -ForegroundColor Cyan
        $globalPackages = cmd /c "npm list -g --depth=0 2>&1"
        Write-Host $globalPackages -ForegroundColor Gray
        
        # Manually install Claude CLI
        Write-Host "`n4. Installing Claude CLI manually..." -ForegroundColor Cyan
        $installResult = cmd /c "npm install -g @anthropic-ai/claude-code 2>&1"
        Write-Host $installResult
        
        # Check if it worked
        Write-Host "`n5. Verifying installation..." -ForegroundColor Cyan
        $claudeVersion = cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        Write-Host "Claude version: $claudeVersion" -ForegroundColor Green
        
        # Return status
        @{
            Success = $claudeVersion -match "Claude Code"
            Version = $claudeVersion
            Path = "$env:APPDATA\npm\claude.cmd"
        }
    }
    
    Write-Host "`nInstallation Result:" -ForegroundColor Yellow
    Write-Host "Success: $($result.Success)" -ForegroundColor $(if($result.Success){'Green'}else{'Red'})
    Write-Host "Version: $($result.Version)" -ForegroundColor Cyan
    Write-Host "Path: $($result.Path)" -ForegroundColor Gray
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}