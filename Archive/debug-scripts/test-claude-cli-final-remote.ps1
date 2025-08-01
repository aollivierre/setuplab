# Final test of Claude CLI installation on remote machine with proper npm handling
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
    # Create session with execution policy bypass
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $RemoteComputer" -ForegroundColor Green
    
    # Set execution policy and test npm
    $npmTest = Invoke-Command -Session $session -ScriptBlock {
        # Set execution policy for the session
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Refresh PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        
        # Test npm using cmd.exe to bypass PowerShell execution policy
        $npmVersion = $null
        try {
            $npmVersion = cmd /c "npm --version 2>&1"
            $npmWorking = $LASTEXITCODE -eq 0
        }
        catch {
            $npmWorking = $false
        }
        
        return @{
            NpmVersion = $npmVersion
            NpmWorking = $npmWorking
        }
    }
    
    Write-Host "`nNPM Status:" -ForegroundColor Cyan
    Write-Host "  Working: $($npmTest.NpmWorking)"
    Write-Host "  Version: $($npmTest.NpmVersion)"
    
    if ($npmTest.NpmWorking) {
        # Copy install script
        Invoke-Command -Session $session -ScriptBlock {
            if (-not (Test-Path "C:\temp")) {
                New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
            }
        }
        
        Write-Host "`nCopying install script..." -ForegroundColor Yellow
        Copy-Item -Path "C:\code\setuplab\install-claude-cli.ps1" -Destination "C:\temp\install-claude-cli.ps1" -ToSession $session -Force
        
        # Create a wrapper script that uses cmd.exe for npm commands
        Write-Host "Creating wrapper script..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ScriptBlock {
            $wrapperContent = @'
# Claude CLI Installation Wrapper
Write-Host "Installing Claude CLI via cmd.exe..." -ForegroundColor Yellow

# Install via cmd
$installCmd = 'npm install -g @anthropic-ai/claude-code'
Write-Host "Running: $installCmd" -ForegroundColor Gray
$output = cmd /c "$installCmd 2>&1"
Write-Host $output

# Get npm prefix via cmd
$npmPrefix = cmd /c "npm config get prefix 2>&1" | Out-String -Stream | Select-Object -First 1
$npmPrefix = $npmPrefix.Trim()
Write-Host "NPM prefix: $npmPrefix" -ForegroundColor Gray

# Check if Claude was installed
$claudePath = Join-Path $npmPrefix "claude.cmd"
if (Test-Path $claudePath) {
    Write-Host "Claude CLI installed at: $claudePath" -ForegroundColor Green
    
    # Update PATH for user
    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentUserPath -notlike "*$npmPrefix*") {
        $newUserPath = if ($currentUserPath) { "$currentUserPath;$npmPrefix" } else { $npmPrefix }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Write-Host "Added $npmPrefix to user PATH" -ForegroundColor Green
    }
    
    # Test Claude
    Write-Host "`nTesting Claude CLI..." -ForegroundColor Yellow
    $version = cmd /c "claude --version 2>&1"
    Write-Host "Version: $version" -ForegroundColor Cyan
}
else {
    Write-Host "Claude CLI was not found after installation" -ForegroundColor Red
}
'@
            $wrapperContent | Out-File -FilePath "C:\temp\install-claude-wrapper.ps1" -Encoding UTF8
        }
        
        # Run the wrapper script
        Write-Host "`nRunning installation..." -ForegroundColor Yellow
        $result = Invoke-Command -Session $session -ScriptBlock {
            try {
                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                $output = & "C:\temp\install-claude-wrapper.ps1" 2>&1 | Out-String
                
                # Check final status
                $npmPrefix = cmd /c "npm config get prefix 2>&1" | Out-String -Stream | Select-Object -First 1
                $npmPrefix = $npmPrefix.Trim()
                $claudePath = Join-Path $npmPrefix "claude.cmd"
                $installed = Test-Path $claudePath
                
                return @{
                    Success = $true
                    Output = $output
                    Installed = $installed
                    ClaudePath = $claudePath
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Display results
        Write-Host "`nResults:" -ForegroundColor Cyan
        if ($result.Success) {
            Write-Host $result.Output
            if ($result.Installed) {
                Write-Host "`nSUCCESS: Claude CLI is installed at $($result.ClaudePath)" -ForegroundColor Green
            }
            else {
                Write-Host "`nFAILED: Claude CLI was not installed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Error: $($result.Error)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`nNPM is not working properly. Please ensure Node.js is installed correctly." -ForegroundColor Red
    }
    
    # Clean up
    Remove-PSSession -Session $session
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}