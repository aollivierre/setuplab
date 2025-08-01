# Simulate fresh system Claude installation
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "SIMULATING FRESH SYSTEM CLAUDE INSTALLATION TEST" -ForegroundColor Magenta
Write-Host "================================================" -ForegroundColor Magenta

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        Write-Host "`n1. SIMULATING FRESH SYSTEM - Removing existing Claude installation..." -ForegroundColor Yellow
        
        # Remove Claude if exists
        if (Test-Path "$env:APPDATA\npm\claude.cmd") {
            cmd /c "npm uninstall -g @anthropic-ai/claude-code 2>&1" | Out-Null
            Write-Host "   - Uninstalled Claude CLI" -ForegroundColor Gray
        }
        
        # Remove npm directory to simulate fresh system
        if (Test-Path "$env:APPDATA\npm") {
            Remove-Item "$env:APPDATA\npm" -Recurse -Force
            Write-Host "   - Removed npm directory" -ForegroundColor Gray
        }
        
        Write-Host "`n2. VERIFYING FRESH STATE..." -ForegroundColor Yellow
        Write-Host "   - npm directory exists: $(Test-Path "$env:APPDATA\npm")" -ForegroundColor Gray
        Write-Host "   - claude.cmd exists: $(Test-Path "$env:APPDATA\npm\claude.cmd")" -ForegroundColor Gray
        
        Write-Host "`n3. DOWNLOADING LATEST install-claude-cli.ps1..." -ForegroundColor Yellow
        $scriptUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
        $scriptPath = "$env:TEMP\install-claude-cli-fresh-test.ps1"
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        
        # Check if our fix is in the script
        $scriptContent = Get-Content $scriptPath -Raw
        $hasNpmDirFix = $scriptContent -match "Creating npm global directory"
        Write-Host "   - Script has npm directory creation fix: $hasNpmDirFix" -ForegroundColor $(if($hasNpmDirFix){'Green'}else{'Red'})
        
        Write-Host "`n4. RUNNING INSTALLATION SCRIPT..." -ForegroundColor Yellow
        try {
            & $scriptPath
            $installSuccess = $true
        } catch {
            Write-Host "   ERROR: $_" -ForegroundColor Red
            $installSuccess = $false
        }
        
        Write-Host "`n5. FINAL VERIFICATION..." -ForegroundColor Yellow
        $finalChecks = @{
            NpmDirExists = Test-Path "$env:APPDATA\npm"
            ClaudeCmdExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            ClaudeVersion = if (Test-Path "$env:APPDATA\npm\claude.cmd") {
                cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            } else {
                "Not installed"
            }
            InstallSuccess = $installSuccess
        }
        
        return $finalChecks
    }
    
    Write-Host "`n=== FRESH SYSTEM TEST RESULTS ===" -ForegroundColor Cyan
    Write-Host "npm directory created: $($result.NpmDirExists)" -ForegroundColor $(if($result.NpmDirExists){'Green'}else{'Red'})
    Write-Host "claude.cmd exists: $($result.ClaudeCmdExists)" -ForegroundColor $(if($result.ClaudeCmdExists){'Green'}else{'Red'})
    Write-Host "Claude version: $($result.ClaudeVersion)" -ForegroundColor $(if($result.ClaudeVersion -match "Claude Code"){'Green'}else{'Red'})
    Write-Host "Installation successful: $($result.InstallSuccess)" -ForegroundColor $(if($result.InstallSuccess){'Green'}else{'Red'})
    
    if ($result.NpmDirExists -and $result.ClaudeCmdExists -and $result.ClaudeVersion -match "Claude Code") {
        Write-Host "`n[DONE] CONFIRMED: The fix WILL work on fresh systems!" -ForegroundColor Green
        Write-Host "The npm directory creation fix ensures installation succeeds even when %APPDATA%\npm doesn't exist." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] ISSUE DETECTED: The fix may not be complete!" -ForegroundColor Red
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}