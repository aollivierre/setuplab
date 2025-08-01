# Simple Claude test
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Simple Claude test..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Just run npm install directly
        Write-Host "Running: npm install -g @anthropic-ai/claude-code" -ForegroundColor Cyan
        
        $output = cmd /c "npm install -g @anthropic-ai/claude-code 2>&1"
        Write-Host $output
        
        # Check result
        $npmDir = "$env:APPDATA\npm"
        $claudeCmd = "$npmDir\claude.cmd"
        
        @{
            NpmDirExists = Test-Path $npmDir
            ClaudeExists = Test-Path $claudeCmd
            NpmDirContents = if (Test-Path $npmDir) { (Get-ChildItem $npmDir).Name -join ", " } else { "N/A" }
        }
    }
    
    Write-Host "`nRESULT:" -ForegroundColor Green
    Write-Host "npm directory exists: $($result.NpmDirExists)"
    Write-Host "Claude exists: $($result.ClaudeExists)"
    Write-Host "npm directory contents: $($result.NpmDirContents)"
    
    if ($result.ClaudeExists) {
        Write-Host "`nSUCCESS! Claude is now installed!" -ForegroundColor Green
        
        # Get version
        $version = Invoke-Command -Session $session -ScriptBlock {
            cmd /c "`"$env:APPDATA\npm\claude.cmd`" --version 2>&1"
        }
        Write-Host "Version: $version" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}