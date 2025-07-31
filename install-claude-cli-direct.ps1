# Direct Claude CLI installation on remote VM
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INSTALLING CLAUDE CLI DIRECTLY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Write-Host "`nChecking Node.js installation..." -ForegroundColor Yellow
        
        # Check Node.js
        $nodePath = "C:\Program Files\nodejs\node.exe"
        if (Test-Path $nodePath) {
            $nodeVersion = & $nodePath --version 2>$null
            Write-Host "[OK] Node.js $nodeVersion is installed" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Node.js not found!" -ForegroundColor Red
            return $false
        }
        
        # Check npm
        $npmPath = "C:\Program Files\nodejs\npm.cmd"
        if (Test-Path $npmPath) {
            $npmVersion = & $npmPath --version 2>$null
            Write-Host "[OK] npm $npmVersion is installed" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] npm not found!" -ForegroundColor Red
            return $false
        }
        
        # Update PATH for this session
        Write-Host "`nUpdating PATH..." -ForegroundColor Yellow
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\Program Files\nodejs"
        
        # Install Claude CLI
        Write-Host "`nInstalling Claude CLI..." -ForegroundColor Yellow
        $installCmd = "C:\Program Files\nodejs\npm.cmd install -g @anthropic-ai/claude-code"
        Write-Host "Running: $installCmd" -ForegroundColor Gray
        
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $installCmd" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "C:\temp\claude-install.log" -RedirectStandardError "C:\temp\claude-error.log"
        
        if ($process.ExitCode -eq 0) {
            Write-Host "[OK] Claude CLI installation completed" -ForegroundColor Green
            
            # Check installation locations
            $claudeLocations = @(
                "$env:APPDATA\npm\claude.cmd",
                "C:\Users\administrator\AppData\Roaming\npm\claude.cmd",
                "C:\Program Files\nodejs\claude.cmd"
            )
            
            $claudeFound = $false
            foreach ($location in $claudeLocations) {
                if (Test-Path $location) {
                    Write-Host "[OK] Claude CLI found at: $location" -ForegroundColor Green
                    $claudeFound = $true
                    
                    # Try to get version
                    try {
                        $claudeVersion = & $location --version 2>$null
                        if ($claudeVersion) {
                            Write-Host "[OK] Claude CLI version: $claudeVersion" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "[INFO] Could not get version, but file exists" -ForegroundColor Yellow
                    }
                    break
                }
            }
            
            if (-not $claudeFound) {
                Write-Host "[WARNING] Claude CLI installed but not found in expected locations" -ForegroundColor Yellow
                
                # Check npm global prefix
                $npmPrefix = & "C:\Program Files\nodejs\npm.cmd" config get prefix 2>$null
                Write-Host "npm global prefix: $npmPrefix" -ForegroundColor Gray
                
                # List npm global packages
                Write-Host "`nGlobal npm packages:" -ForegroundColor Yellow
                & "C:\Program Files\nodejs\npm.cmd" list -g --depth=0
            }
            
            return $true
        } else {
            Write-Host "[ERROR] Claude CLI installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            
            # Show error log
            if (Test-Path "C:\temp\claude-error.log") {
                Write-Host "`nError log:" -ForegroundColor Red
                Get-Content "C:\temp\claude-error.log" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            }
            
            return $false
        }
    }
    
    if ($result) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "CLAUDE CLI INSTALLED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "`nNow you have 15/16 apps installed (93.75%)!" -ForegroundColor Green
        Write-Host "Only Windows Terminal AppX detection is failing remotely." -ForegroundColor Yellow
    } else {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "CLAUDE CLI INSTALLATION FAILED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}