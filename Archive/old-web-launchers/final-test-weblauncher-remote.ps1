# Final test of web launcher with all fixes
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

Write-Host "Waiting 10 seconds for GitHub to update..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nRunning final test on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $RemoteComputer" -ForegroundColor Green
    
    # Clean up any previous Claude installation first
    Write-Host "Cleaning up previous installation..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Remove Claude if it exists
        if (Test-Path "$env:APPDATA\npm\claude.cmd") {
            Remove-Item "$env:APPDATA\npm\claude*" -Force -ErrorAction SilentlyContinue
        }
        
        # Clear npm cache
        cmd /c "npm cache clean --force 2>&1" | Out-Null
    }
    
    # Run the web launcher
    Write-Host "`nRunning web launcher..." -ForegroundColor Yellow
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Run the web launcher - limit output to prevent timeout
            $output = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
            
            # Get just the summary
            $lines = $output -split "`n"
            $summaryStart = $lines.IndexOf("[Info] Installation Summary:")
            $summaryLines = if ($summaryStart -ge 0) {
                $lines[$summaryStart..($summaryStart + 20)]
            } else {
                $lines[-20..-1]
            }
            
            return @{
                Success = $true
                Summary = $summaryLines -join "`n"
                ClaudeInstalled = $output -match "Claude CLI installed successfully"
                ClaudeFailed = $output -match "Failed to install Claude CLI"
            }
        }
        catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    if ($result.Success) {
        Write-Host "`nInstallation completed!" -ForegroundColor Green
        Write-Host "`nSummary:" -ForegroundColor Cyan
        Write-Host $result.Summary
        
        if ($result.ClaudeInstalled) {
            Write-Host "`n[OK] Claude CLI installed successfully!" -ForegroundColor Green
        } elseif ($result.ClaudeFailed) {
            Write-Host "`n[FAIL] Claude CLI installation failed" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Installation failed: $($result.Error)" -ForegroundColor Red
    }
    
    # Final verification
    Write-Host "`n`nFinal verification..." -ForegroundColor Yellow
    $verify = Invoke-Command -Session $session -ScriptBlock {
        $claudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
        $version = if ($claudeExists) {
            cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        
        return @{
            Exists = $claudeExists
            Version = $version
        }
    }
    
    Write-Host "Claude CLI exists: $($verify.Exists)"
    if ($verify.Version) {
        Write-Host "Claude CLI version: $($verify.Version)" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}