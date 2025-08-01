# Wait for system to be ready and test Claude
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Waiting for remote system to be ready..." -ForegroundColor Yellow

# Try to connect for up to 2 minutes
$maxAttempts = 24
$attempt = 0
$connected = $false

while ($attempt -lt $maxAttempts -and -not $connected) {
    $attempt++
    Write-Host "Connection attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    
    try {
        $testSession = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
        Remove-PSSession $testSession
        $connected = $true
        Write-Host "Connected successfully!" -ForegroundColor Green
    }
    catch {
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $connected) {
    Write-Host "Failed to connect after $maxAttempts attempts" -ForegroundColor Red
    return
}

Write-Host "`nSystem is ready. Testing Claude installation..." -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Just run the web launcher directly
    Write-Host "`nRunning SetupLab Web Launcher on fresh system..." -ForegroundColor Yellow
    
    Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "Starting installation..." -ForegroundColor Green
        
        # Run the web launcher
        iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
}