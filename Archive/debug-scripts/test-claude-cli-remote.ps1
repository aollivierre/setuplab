# Test Claude CLI installation on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Testing Claude CLI installation on $RemoteComputer..." -ForegroundColor Yellow

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $RemoteComputer" -ForegroundColor Green
    
    # Create temp directory on remote machine if it doesn't exist
    Invoke-Command -Session $session -ScriptBlock {
        if (-not (Test-Path "C:\temp")) {
            New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        }
    }
    
    # Copy the fixed install-claude-cli.ps1 to remote machine
    Write-Host "`nCopying install-claude-cli.ps1 to remote machine..." -ForegroundColor Yellow
    Copy-Item -Path "C:\code\setuplab\install-claude-cli.ps1" -Destination "C:\temp\install-claude-cli.ps1" -ToSession $session -Force
    
    # Run the Claude CLI installation script
    Write-Host "`nRunning Claude CLI installation..." -ForegroundColor Yellow
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Set execution policy for the session
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Run the installation script
            $output = & "C:\temp\install-claude-cli.ps1" 2>&1
            
            # Check if Claude CLI was installed
            $claudePath = "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
            $claudeInstalled = Test-Path $claudePath
            
            # Try to get version
            $claudeVersion = $null
            if ($claudeInstalled) {
                try {
                    $claudeVersion = & cmd /c "claude --version 2>&1"
                } catch {
                    $claudeVersion = "Could not get version"
                }
            }
            
            return @{
                Success = $true
                Output = $output -join "`n"
                ClaudeInstalled = $claudeInstalled
                ClaudeVersion = $claudeVersion
                Error = $null
            }
        }
        catch {
            return @{
                Success = $false
                Output = $null
                ClaudeInstalled = $false
                ClaudeVersion = $null
                Error = $_.Exception.Message
            }
        }
    }
    
    # Display results
    if ($result.Success) {
        Write-Host "`nInstallation script executed successfully!" -ForegroundColor Green
        Write-Host "`nOutput:" -ForegroundColor Cyan
        Write-Host $result.Output
        
        if ($result.ClaudeInstalled) {
            Write-Host "`nClaude CLI is installed!" -ForegroundColor Green
            Write-Host "Version: $($result.ClaudeVersion)" -ForegroundColor Cyan
        }
        else {
            Write-Host "`nClaude CLI was NOT found after installation" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`nInstallation failed!" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
    }
    
    # Test running the web launcher with Claude CLI enabled
    Write-Host "`n`nTesting full SetupLab web launcher..." -ForegroundColor Yellow
    
    $webResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Run the web launcher
            $output = iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') 2>&1
            
            return @{
                Success = $true
                Output = $output -join "`n"
            }
        }
        catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    if ($webResult.Success) {
        Write-Host "`nWeb launcher completed!" -ForegroundColor Green
        # Show last 20 lines of output
        $lines = $webResult.Output -split "`n"
        $lastLines = $lines[-20..-1]
        Write-Host "`nLast 20 lines of output:" -ForegroundColor Cyan
        $lastLines | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "`nWeb launcher failed!" -ForegroundColor Red
        Write-Host "Error: $($webResult.Error)" -ForegroundColor Red
    }
    
    # Cleanup
    Remove-PSSession -Session $session
    Write-Host "`nRemote testing completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
}