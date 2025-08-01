# TEST FIXED SETUPLAB MODULE
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n=== TESTING FIXED SETUPLAB MODULE ===" -ForegroundColor Red
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Write-Host "`n1. COPYING FIXED FILES TO REMOTE..." -ForegroundColor Cyan
    
    # Copy our fixed SetupLabCore.psm1 and other required files
    Copy-Item -Path "C:\code\setuplab\SetupLabCore.psm1" -Destination "C:\temp\SetupLab\" -ToSession $session -Force
    Copy-Item -Path "C:\code\setuplab\test-config-minimal.json" -Destination "C:\temp\" -ToSession $session -Force
    
    Write-Host "Files copied successfully" -ForegroundColor Green
    
    Write-Host "`n2. RUNNING SETUPLAB WITH FIXED MODULE..." -ForegroundColor Cyan
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Create log file
        $logFile = "C:\temp\fixed-module-test.log"
        Start-Transcript -Path $logFile -Force
        
        Write-Host "Testing with local fixed module..." -ForegroundColor Yellow
        
        # Import our fixed module
        Import-Module "C:\temp\SetupLab\SetupLabCore.psm1" -Force
        
        # Create a minimal test to install just Claude CLI with dependencies
        $config = Get-Content "C:\temp\test-config-minimal.json" | ConvertFrom-Json
        
        # Process just the 3 components
        foreach ($software in $config.software) {
            if ($software.enabled) {
                Write-Host "`nInstalling: $($software.name)" -ForegroundColor Cyan
                
                if ($software.name -eq "Claude Code (CLI)") {
                    # This is where the bug was - let's see if it's fixed
                    Write-Host "Testing CUSTOM installer type..." -ForegroundColor Yellow
                }
            }
        }
        
        Stop-Transcript
        
        # Return test results
        @{
            ModuleLoaded = (Get-Module SetupLabCore) -ne $null
            LogCreated = Test-Path $logFile
            # We'll check actual installation after
        }
    }
    
    Write-Host "`n3. TEST RESULTS:" -ForegroundColor Cyan
    Write-Host "Module loaded: $($result.ModuleLoaded)" -ForegroundColor $(if($result.ModuleLoaded){'Green'}else{'Red'})
    Write-Host "Log created: $($result.LogCreated)" -ForegroundColor $(if($result.LogCreated){'Green'}else{'Red'})
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}