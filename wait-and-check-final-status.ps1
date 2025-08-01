# Wait and check final status
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Waiting 30 seconds for installation to progress..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`nChecking final status..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Final check
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        $npmDir = "$env:APPDATA\npm"
        
        @{
            # Check npm directory
            NpmDirExists = Test-Path $npmDir
            NpmDirContents = if (Test-Path $npmDir) { 
                (Get-ChildItem $npmDir -ErrorAction SilentlyContinue).Name -join ", "
            } else { 
                "Directory not found" 
            }
            
            # Check Claude
            ClaudeExists = Test-Path $claudePath
            ClaudeVersion = if (Test-Path $claudePath) {
                cmd /c "`"$claudePath`" --version 2>&1"
            } else {
                "Not installed"
            }
            
            # Check if Node.js is installed (prerequisite)
            NodeVersion = cmd /c "node --version 2>&1"
            NpmVersion = cmd /c "npm --version 2>&1"
            
            # Get process status
            ActiveProcesses = (Get-Process | Where-Object { $_.Name -match "msiexec|setup|install|node" }).Count
        }
    }
    
    Write-Host "`n=== FINAL STATUS ===" -ForegroundColor Green
    Write-Host "Node.js: $($result.NodeVersion)" -ForegroundColor Gray
    Write-Host "npm: $($result.NpmVersion)" -ForegroundColor Gray
    Write-Host "npm directory exists: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    
    if ($result.NpmDirExists) {
        Write-Host "npm directory contents: $($result.NpmDirContents)" -ForegroundColor Gray
    }
    
    Write-Host "Claude installed: $($result.ClaudeExists)" -ForegroundColor $(if($result.ClaudeExists){'Green'}else{'Red'})
    Write-Host "Claude version: $($result.ClaudeVersion)" -ForegroundColor $(if($result.ClaudeVersion -match "Claude Code"){'Green'}else{'Yellow'})
    
    if ($result.ActiveProcesses -gt 0) {
        Write-Host "`nNote: $($result.ActiveProcesses) installation processes still active" -ForegroundColor Yellow
    }
    
    if ($result.ClaudeExists -and $result.ClaudeVersion -match "Claude Code") {
        Write-Host "`n[DONE] SUCCESS! Claude Code is installed on the fresh system!" -ForegroundColor Green
        Write-Host "The fix worked perfectly!" -ForegroundColor Green
    } elseif ($result.NodeVersion -match "v\d+" -and -not $result.ClaudeExists) {
        Write-Host "`n[WARNING] Node.js is installed but Claude is not yet installed" -ForegroundColor Yellow
        Write-Host "The installation may still be running or Claude installation step hasn't been reached yet" -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}