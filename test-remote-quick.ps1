# Quick test of SetupLab on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

# Create credentials
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Quick remote test of SetupLab..." -ForegroundColor Yellow

try {
    # Create session
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Run web launcher remotely with -WhatIf to test
    Write-Host "`nTesting web launcher remotely..." -ForegroundColor Yellow
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Download and run the web launcher
            $webLauncherUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing/SetupLab-WebLauncher-NoCache.ps1"
            $webLauncher = Invoke-WebRequest -Uri $webLauncherUrl -UseBasicParsing
            
            # Save to temp file
            $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
            $webLauncher.Content | Out-File -FilePath $tempFile -Encoding UTF8
            
            # Run with -ListSoftware to just list available software
            $output = & $tempFile -ListSoftware -BaseUrl "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing" 2>&1
            
            # Clean up
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
            return @{
                Success = $true
                Output = $output
            }
        }
        catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                StackTrace = $_.Exception.StackTrace
            }
        }
    }
    
    if ($result.Success) {
        Write-Host "`nWeb launcher test successful!" -ForegroundColor Green
        Write-Host "`nAvailable software:" -ForegroundColor Cyan
        $result.Output | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "`nWeb launcher test failed!" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
        Write-Host $result.StackTrace -ForegroundColor DarkGray
    }
    
    # Test specific fixes
    Write-Host "`nTesting specific fixes..." -ForegroundColor Yellow
    
    $testResults = Invoke-Command -Session $session -ScriptBlock {
        $tests = @()
        
        # Test 1: Check if execution policy can be set
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            $tests += @{Test="Execution Policy"; Result="Pass"; Details="Set to Bypass successfully"}
        }
        catch {
            $tests += @{Test="Execution Policy"; Result="Fail"; Details=$_.Exception.Message}
        }
        
        # Test 2: Download a test file
        try {
            $testUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/enhanced-logging-remote-testing/software-config.json"
            $content = Invoke-WebRequest -Uri $testUrl -UseBasicParsing
            if ($content.Content.Length -gt 0) {
                $tests += @{Test="Web Download"; Result="Pass"; Details="Downloaded software-config.json"}
            }
        }
        catch {
            $tests += @{Test="Web Download"; Result="Fail"; Details=$_.Exception.Message}
        }
        
        # Test 3: Check PowerShell version
        $psVersion = $PSVersionTable.PSVersion
        $tests += @{Test="PowerShell Version"; Result="Info"; Details="$($psVersion.Major).$($psVersion.Minor).$($psVersion.Build)"}
        
        # Test 4: Check if Node.js is installed
        $nodePath = "C:\Program Files\nodejs\node.exe"
        if (Test-Path $nodePath) {
            $nodeVersion = & $nodePath --version 2>$null
            $tests += @{Test="Node.js"; Result="Installed"; Details="Version: $nodeVersion"}
        }
        else {
            $tests += @{Test="Node.js"; Result="Not Installed"; Details="Path not found"}
        }
        
        return $tests
    }
    
    Write-Host "`nTest Results:" -ForegroundColor Cyan
    $testResults | ForEach-Object {
        $color = switch ($_.Result) {
            "Pass" { "Green" }
            "Fail" { "Red" }
            "Info" { "Yellow" }
            "Installed" { "Green" }
            "Not Installed" { "Yellow" }
            default { "Gray" }
        }
        Write-Host "$($_.Test): $($_.Result) - $($_.Details)" -ForegroundColor $color
    }
    
    # Cleanup
    Remove-PSSession -Session $session
    Write-Host "`nQuick test completed!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}