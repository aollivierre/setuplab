# TEST COMPLETE FIX - ONLY 3 COMPONENTS
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING COMPLETE FIX - 3 COMPONENTS ONLY ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. Running SetupLab with 3 components only..." -ForegroundColor Cyan
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create minimal config
        New-Item -Path "C:\code" -ItemType Directory -Force | Out-Null
        
        # Simple approach - just run with Software parameter
        Write-Host "Running web launcher with Software filter..." -ForegroundColor Yellow
        
        try {
            # Use the Software parameter to limit what gets installed
            iex ((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') + ' -Software @("Git", "Node.js", "Claude Code (CLI)")')
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
        }
    }
    
    # Wait for installation
    Write-Host "`n2. Waiting 2 minutes for installation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120
    
    Write-Host "`n3. Checking results..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        @{
            Git = Test-Path "C:\Program Files\Git\bin\git.exe"
            Node = Test-Path "C:\Program Files\nodejs\node.exe"
            NpmDir = Test-Path "$env:APPDATA\npm"
            Claude = Test-Path "$env:APPDATA\npm\claude.cmd"
            Version = if (Test-Path "$env:APPDATA\npm\claude.cmd") {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            } else { "Not installed" }
        }
    }
    
    Write-Host "`nRESULTS:" -ForegroundColor Yellow
    Write-Host "Git: $($result.Git)" -ForegroundColor $(if($result.Git){'Green'}else{'Red'})
    Write-Host "Node.js: $($result.Node)" -ForegroundColor $(if($result.Node){'Green'}else{'Red'})
    Write-Host "npm dir: $($result.NpmDir)" -ForegroundColor $(if($result.NpmDir){'Green'}else{'Red'})
    Write-Host "Claude: $($result.Claude)" -ForegroundColor $(if($result.Claude){'Green'}else{'Red'})
    
    if ($result.Claude) {
        Write-Host "`n✓ SUCCESS! Claude version: $($result.Version)" -ForegroundColor Green
    } else {
        Write-Host "`n✗ FAILED! Claude not installed" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}