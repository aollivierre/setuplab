# Verify Claude CLI is working on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Verifying Claude CLI on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $verification = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        # Check Claude CLI
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        $results.ClaudeExists = Test-Path $claudePath
        
        if ($results.ClaudeExists) {
            # Get version
            $results.Version = cmd /c "`"$claudePath`" --version 2>&1"
            
            # Try claude doctor
            $results.Doctor = cmd /c "`"$claudePath`" doctor 2>&1" | Out-String
        }
        
        # Check npm packages
        $results.NpmList = cmd /c "npm list -g @anthropic-ai/claude-code 2>&1" | Out-String
        
        return $results
    }
    
    Write-Host "`nClaude CLI Status:" -ForegroundColor Cyan
    Write-Host "  Exists: $($verification.ClaudeExists)"
    
    if ($verification.Version) {
        Write-Host "  Version: $($verification.Version)" -ForegroundColor Green
    }
    
    if ($verification.NpmList) {
        Write-Host "`nNPM Global Packages:" -ForegroundColor Yellow
        Write-Host $verification.NpmList
    }
    
    if ($verification.Doctor) {
        Write-Host "`nClaude Doctor Output:" -ForegroundColor Yellow
        Write-Host $verification.Doctor
    }
    
    Remove-PSSession -Session $session
    Write-Host "`nVerification complete!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}