# Compare execution contexts to find the difference
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Comparing execution contexts on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # First test: Direct execution (WORKS)
    Write-Host "`n1. Testing DIRECT execution (what works)..." -ForegroundColor Green
    $directResult = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        $script = "$env:TEMP\test-direct.ps1"
        $testContent = @'
Write-Host "Testing environment..."
Write-Host "PSScriptRoot: $PSScriptRoot"
Write-Host "MyInvocation.PSScriptRoot: $($MyInvocation.PSScriptRoot)"
Write-Host "ExecutionContext: $($ExecutionContext.SessionState.Path.CurrentLocation)"

# Test the problematic line
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
Write-Host "User PATH length: $($currentPath.Length)"
Write-Host "First 100 chars: $($currentPath.Substring(0, [Math]::Min(100, $currentPath.Length)))"
'@
        $testContent | Out-File -FilePath $script -Encoding UTF8
        & $script
    }
    
    # Second test: Module context (FAILS)
    Write-Host "`n2. Testing MODULE context (what fails)..." -ForegroundColor Red
    $moduleResult = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create a minimal module that mimics SetupLabCore
        $moduleContent = @'
function Invoke-CustomScript {
    param($ScriptPath)
    
    Write-Host "Module PSScriptRoot: $PSScriptRoot"
    Write-Host "Executing from module context..."
    
    $scriptDir = Split-Path $ScriptPath -Parent
    Push-Location $scriptDir
    try {
        & $ScriptPath
    } finally {
        Pop-Location
    }
}

Export-ModuleMember -Function Invoke-CustomScript
'@
        $modulePath = "$env:TEMP\TestModule.psm1"
        $moduleContent | Out-File -FilePath $modulePath -Encoding UTF8
        
        Import-Module $modulePath -Force
        
        # Create test script
        $script = "$env:TEMP\test-module.ps1"
        $testContent = @'
Write-Host "Testing from module-invoked script..."
Write-Host "PSScriptRoot: $PSScriptRoot"
Write-Host "MyInvocation.PSScriptRoot: $($MyInvocation.PSScriptRoot)"

# Test the problematic line
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "User PATH success! Length: $($currentPath.Length)"
} catch {
    Write-Host "ERROR getting User PATH: $_"
    Write-Host "Error Type: $($_.Exception.GetType().FullName)"
}
'@
        $testContent | Out-File -FilePath $script -Encoding UTF8
        
        # Invoke through module
        Invoke-CustomScript -ScriptPath $script
    }
    
    Write-Host "`nDirect execution output:" -ForegroundColor Green
    $directResult
    
    Write-Host "`nModule execution output:" -ForegroundColor Red
    $moduleResult
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}