# QUICK CLAUDE TEST
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nQuick Claude test..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Just test Claude install directly
    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "Testing direct Claude installation..." -ForegroundColor Cyan
        
        # Check current state
        $claudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
        $npmDirExists = Test-Path "$env:APPDATA\npm"
        
        Write-Host "npm dir exists: $npmDirExists"
        Write-Host "Claude exists: $claudeExists"
        
        if (-not $claudeExists) {
            Write-Host "`nInstalling Claude directly..." -ForegroundColor Yellow
            $output = cmd /c "npm install -g @anthropic-ai/claude-code 2>&1"
            Write-Host $output
            
            # Check again
            $claudeExists = Test-Path "$env:APPDATA\npm\claude.cmd"
            Write-Host "`nAfter install - Claude exists: $claudeExists" -ForegroundColor $(if($claudeExists){'Green'}else{'Red'})
        }
        
        if ($claudeExists) {
            $version = cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
            Write-Host "Claude version: $version" -ForegroundColor Green
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}