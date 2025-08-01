# Fix npm PATH and test Claude CLI on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Fixing npm PATH and testing Claude CLI on $RemoteComputer..." -ForegroundColor Yellow

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $RemoteComputer" -ForegroundColor Green
    
    # Check Node.js installation and fix PATH
    $nodeInfo = Invoke-Command -Session $session -ScriptBlock {
        $info = @{}
        
        # Check if Node.js is installed
        $nodePath = "C:\Program Files\nodejs\node.exe"
        $npmPath = "C:\Program Files\nodejs\npm.cmd"
        
        $info.NodeExists = Test-Path $nodePath
        $info.NpmExists = Test-Path $npmPath
        
        if ($info.NodeExists) {
            $info.NodeVersion = & $nodePath --version 2>&1
        }
        
        # Get current PATH
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $currentPath = $env:Path
        
        $info.NodejsInMachinePath = $machinePath -like "*nodejs*"
        $info.NodejsInUserPath = $userPath -like "*nodejs*"
        $info.NodejsInCurrentPath = $currentPath -like "*nodejs*"
        
        # Fix PATH if needed
        if ($info.NodeExists -and -not $info.NodejsInMachinePath) {
            Write-Host "Adding Node.js to Machine PATH..." -ForegroundColor Yellow
            $newMachinePath = $machinePath + ";C:\Program Files\nodejs"
            [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
            $info.PathFixed = $true
        }
        
        # Refresh current session PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        
        # Test npm after PATH fix
        try {
            $info.NpmVersion = npm --version 2>&1
            $info.NpmWorking = $true
        }
        catch {
            $info.NpmWorking = $false
            $info.NpmError = $_.Exception.Message
        }
        
        return $info
    }
    
    # Display Node.js status
    Write-Host "`nNode.js Status:" -ForegroundColor Cyan
    Write-Host "  Node.exe exists: $($nodeInfo.NodeExists)"
    Write-Host "  npm.cmd exists: $($nodeInfo.NpmExists)"
    if ($nodeInfo.NodeVersion) {
        Write-Host "  Node version: $($nodeInfo.NodeVersion)"
    }
    Write-Host "  Node.js in Machine PATH: $($nodeInfo.NodejsInMachinePath)"
    Write-Host "  Node.js in User PATH: $($nodeInfo.NodejsInUserPath)"
    Write-Host "  npm working: $($nodeInfo.NpmWorking)"
    if ($nodeInfo.NpmVersion) {
        Write-Host "  npm version: $($nodeInfo.NpmVersion)"
    }
    if ($nodeInfo.PathFixed) {
        Write-Host "  PATH was fixed!" -ForegroundColor Green
    }
    
    if (-not $nodeInfo.NpmWorking) {
        Write-Host "`nNode.js/npm is not properly installed or configured" -ForegroundColor Red
        if ($nodeInfo.NpmError) {
            Write-Host "Error: $($nodeInfo.NpmError)" -ForegroundColor Red
        }
    }
    else {
        # Now try to install Claude CLI
        Write-Host "`nNode.js is working! Installing Claude CLI..." -ForegroundColor Green
        
        # Copy and run install script
        Invoke-Command -Session $session -ScriptBlock {
            if (-not (Test-Path "C:\temp")) {
                New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
            }
        }
        
        Copy-Item -Path "C:\code\setuplab\install-claude-cli.ps1" -Destination "C:\temp\install-claude-cli.ps1" -ToSession $session -Force
        
        $installResult = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Refresh PATH again
                $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                
                # Run install script
                $output = & "C:\temp\install-claude-cli.ps1" 2>&1 | Out-String
                
                # Check if Claude was installed
                $npmPrefix = npm config get prefix 2>$null
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
        
        if ($installResult.Success) {
            Write-Host "`nInstallation output:" -ForegroundColor Yellow
            Write-Host $installResult.Output
            
            if ($installResult.Installed) {
                Write-Host "`nClaude CLI installed successfully at: $($installResult.ClaudePath)" -ForegroundColor Green
            }
            else {
                Write-Host "`nClaude CLI installation may have failed" -ForegroundColor Red
            }
        }
        else {
            Write-Host "`nInstallation failed: $($installResult.Error)" -ForegroundColor Red
        }
    }
    
    # Clean up
    Remove-PSSession -Session $session
    Write-Host "`nCompleted!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}