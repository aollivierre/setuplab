# Test complete installation on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

Write-Host "Waiting for GitHub update..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Testing on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Just check if Claude CLI is installed
    $check = Invoke-Command -Session $session -ScriptBlock {
        @{
            ClaudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            NpmVersion = cmd /c "npm --version 2>&1"
        }
    }
    
    Write-Host "Current status:"
    Write-Host "  Claude CLI exists: $($check.ClaudeExists)"
    Write-Host "  NPM version: $($check.NpmVersion)"
    
    if (-not $check.ClaudeExists) {
        Write-Host "`nRunning web launcher to install Claude CLI..." -ForegroundColor Yellow
        
        # Run just the Claude CLI part
        $installResult = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Download and run just the Claude CLI installer
                $url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
                $script = Invoke-WebRequest -Uri $url -UseBasicParsing
                $scriptPath = "$env:TEMP\install-claude-cli-direct.ps1"
                $script.Content | Out-File -FilePath $scriptPath -Encoding UTF8
                
                # Run it
                $output = & $scriptPath 2>&1 | Out-String
                
                return @{
                    Success = $true
                    Output = $output
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        if ($installResult.Success) {
            Write-Host "`nInstallation output:" -ForegroundColor Green
            Write-Host $installResult.Output
        }
        else {
            Write-Host "`nInstallation failed: $($installResult.Error)" -ForegroundColor Red
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}