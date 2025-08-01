# Quick check of Claude CLI installation result
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking Claude CLI on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Check Claude CLI
        $claudePath = "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
        $exists = Test-Path $claudePath
        
        $version = $null
        if ($exists) {
            try {
                $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                $version = cmd /c "claude --version 2>&1"
            } catch {
                $version = "Error getting version"
            }
        }
        
        # Check npm
        $npmVersion = cmd /c "npm --version 2>&1"
        
        return @{
            ClaudeExists = $exists
            ClaudePath = $claudePath
            ClaudeVersion = $version
            NpmVersion = $npmVersion
        }
    }
    
    Write-Host "`nResults:" -ForegroundColor Cyan
    Write-Host "  NPM Version: $($result.NpmVersion)"
    Write-Host "  Claude Exists: $($result.ClaudeExists)"
    Write-Host "  Claude Path: $($result.ClaudePath)"
    if ($result.ClaudeVersion) {
        Write-Host "  Claude Version: $($result.ClaudeVersion)" -ForegroundColor $(if($result.ClaudeExists){"Green"}else{"Red"})
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}