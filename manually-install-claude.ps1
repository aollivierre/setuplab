# Manually install Claude to test our fix
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`nManually testing Claude installation..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        Write-Host "`n1. Downloading latest install-claude-cli.ps1..." -ForegroundColor Yellow
        $scriptUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
        $scriptPath = "$env:TEMP\manual-claude-install.ps1"
        
        try {
            Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
            Write-Host "Downloaded successfully" -ForegroundColor Green
            
            # Check if our fix is in the file
            $content = Get-Content $scriptPath -Raw
            if ($content -match "Creating npm global directory") {
                Write-Host "✓ npm directory creation fix is present" -ForegroundColor Green
            } else {
                Write-Host "✗ npm directory creation fix is MISSING!" -ForegroundColor Red
            }
            
            Write-Host "`n2. Running installation..." -ForegroundColor Yellow
            & $scriptPath
            
            Write-Host "`n3. Final verification..." -ForegroundColor Yellow
            $claudePath = "$env:APPDATA\npm\claude.cmd"
            if (Test-Path $claudePath) {
                Write-Host "✓ Claude installed successfully!" -ForegroundColor Green
                $version = cmd /c "`"$claudePath`" --version 2>&1"
                Write-Host "Version: $version" -ForegroundColor Green
            } else {
                Write-Host "✗ Claude not found after installation" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
            Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}