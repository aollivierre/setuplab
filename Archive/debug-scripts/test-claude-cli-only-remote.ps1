# Test only Claude CLI installation on remote machine
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
    
    # Create temp directory and copy script
    Invoke-Command -Session $session -ScriptBlock {
        if (-not (Test-Path "C:\temp")) {
            New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        }
    }
    
    Write-Host "Copying install-claude-cli.ps1 to remote machine..." -ForegroundColor Yellow
    Copy-Item -Path "C:\code\setuplab\install-claude-cli.ps1" -Destination "C:\temp\install-claude-cli.ps1" -ToSession $session -Force
    
    # Run the installation
    Write-Host "`nRunning Claude CLI installation script..." -ForegroundColor Yellow
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            
            # Check if Node.js is installed first
            $nodePath = "C:\Program Files\nodejs\node.exe"
            if (-not (Test-Path $nodePath)) {
                return @{
                    Success = $false
                    Error = "Node.js is not installed. Please install Node.js first."
                }
            }
            
            # Run the script and capture output
            $output = & "C:\temp\install-claude-cli.ps1" 2>&1 | Out-String
            
            # Check if Claude was installed
            $npmPrefix = npm config get prefix 2>$null
            $claudePath = Join-Path $npmPrefix "claude.cmd"
            $installed = Test-Path $claudePath
            
            # Try to get version
            $version = $null
            if ($installed) {
                try {
                    # Refresh PATH
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    $version = & claude --version 2>&1 | Out-String
                } catch {
                    $version = "Could not get version"
                }
            }
            
            return @{
                Success = $true
                Output = $output
                Installed = $installed
                ClaudePath = $claudePath
                Version = $version
            }
        }
        catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
        }
    }
    
    # Display results
    if ($result.Success) {
        Write-Host "`nScript execution completed!" -ForegroundColor Green
        
        if ($result.Installed) {
            Write-Host "`nClaude CLI is installed at: $($result.ClaudePath)" -ForegroundColor Green
            Write-Host "Version: $($result.Version)" -ForegroundColor Cyan
        }
        else {
            Write-Host "`nClaude CLI was NOT installed" -ForegroundColor Red
        }
        
        Write-Host "`nInstallation output:" -ForegroundColor Yellow
        Write-Host $result.Output
    }
    else {
        Write-Host "`nInstallation failed!" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
        if ($result.StackTrace) {
            Write-Host "`nStack trace:" -ForegroundColor DarkGray
            Write-Host $result.StackTrace
        }
    }
    
    # Clean up
    Remove-PSSession -Session $session
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
}