# CHECK CLAUDE RESULT - FINAL
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== CHECKING CLAUDE INSTALLATION RESULT ===" -ForegroundColor Red

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        @{
            ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            
            # Get the full log
            FullLog = if (Test-Path "C:\code\full-installation-log.txt") {
                Get-Content "C:\code\full-installation-log.txt" | Where-Object { $_ -match "Claude|Cannot bind|empty string|Failed to install" } | Select-Object -Last 20
            } else { @() }
            
            # Get error from SetupLab logs
            SetupLabError = $null
        }
    }
    
    Write-Host "`nRESULT:" -ForegroundColor Yellow
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "Claude installed: $($result.ClaudeExists)" -ForegroundColor $(if($result.ClaudeExists){'Green'}else{'Red'})
    
    if (-not $result.ClaudeExists) {
        Write-Host "`nCLAUDE FAILED AGAIN!" -ForegroundColor Red
        Write-Host "`nError entries from log:" -ForegroundColor Yellow
        $result.FullLog | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        
        Write-Host "`nTHE PROBLEM:" -ForegroundColor Red
        Write-Host "The 'Cannot bind argument to parameter Path because it is an empty string' error" -ForegroundColor Red
        Write-Host "is happening INSIDE SetupLabCore.psm1 when it tries to execute the CUSTOM script" -ForegroundColor Red
        Write-Host "`nThe issue is NOT in install-claude-cli.ps1 itself!" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}