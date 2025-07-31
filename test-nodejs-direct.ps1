# Test Node.js installation directly
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DIRECT NODE.JS INSTALLATION TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Test different installation methods
    $result = Invoke-Command -Session $session -ScriptBlock {
        Write-Host "`nTesting Node.js installation methods..." -ForegroundColor Yellow
        
        # Kill any stuck Node.js processes
        Get-Process -Name "*node*", "*msiexec*" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        
        # Download Node.js MSI
        $url = "https://nodejs.org/dist/v22.17.1/node-v22.17.1-x64.msi"
        $msiPath = "C:\temp\nodejs.msi"
        
        if (-not (Test-Path "C:\temp")) {
            New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        }
        
        Write-Host "Downloading Node.js MSI..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
        
        # Method 1: Simple /qn
        Write-Host "`nMethod 1: Using /qn only..." -ForegroundColor Yellow
        $process1 = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn" -Wait -PassThru
        Write-Host "Exit code: $($process1.ExitCode)" -ForegroundColor $(if ($process1.ExitCode -eq 0) { "Green" } else { "Red" })
        
        # Check if installed
        $nodeExe = "C:\Program Files\nodejs\node.exe"
        if (Test-Path $nodeExe) {
            $version = & $nodeExe --version 2>$null
            Write-Host "SUCCESS: Node.js $version installed!" -ForegroundColor Green
            return @{
                Success = $true
                Method = "/qn only"
                Version = $version
                ExitCode = $process1.ExitCode
            }
        }
        
        # Method 2: With /norestart
        Write-Host "`nMethod 2: Using /qn /norestart..." -ForegroundColor Yellow
        $process2 = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
        Write-Host "Exit code: $($process2.ExitCode)" -ForegroundColor $(if ($process2.ExitCode -eq 0) { "Green" } else { "Red" })
        
        if (Test-Path $nodeExe) {
            $version = & $nodeExe --version 2>$null
            Write-Host "SUCCESS: Node.js $version installed!" -ForegroundColor Green
            return @{
                Success = $true
                Method = "/qn /norestart"
                Version = $version
                ExitCode = $process2.ExitCode
            }
        }
        
        # Method 3: With logging
        Write-Host "`nMethod 3: With logging..." -ForegroundColor Yellow
        $logPath = "C:\temp\nodejs_install.log"
        $process3 = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart /l*v `"$logPath`"" -Wait -PassThru
        Write-Host "Exit code: $($process3.ExitCode)" -ForegroundColor $(if ($process3.ExitCode -eq 0) { "Green" } else { "Red" })
        
        if (Test-Path $nodeExe) {
            $version = & $nodeExe --version 2>$null
            Write-Host "SUCCESS: Node.js $version installed!" -ForegroundColor Green
            return @{
                Success = $true
                Method = "With logging"
                Version = $version
                ExitCode = $process3.ExitCode
            }
        }
        
        # Check log file for errors
        if (Test-Path $logPath) {
            Write-Host "`nChecking installation log..." -ForegroundColor Yellow
            $logErrors = Get-Content $logPath | Select-String -Pattern "error|fail" -CaseSensitive:$false | Select-Object -First 10
            if ($logErrors) {
                Write-Host "Errors found in log:" -ForegroundColor Red
                $logErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            }
            
            # Get last 20 lines
            Write-Host "`nLast 20 lines of log:" -ForegroundColor Yellow
            Get-Content $logPath | Select-Object -Last 20
        }
        
        # Check MSI database
        Write-Host "`nChecking MSI properties..." -ForegroundColor Yellow
        try {
            $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
            $database = $windowsInstaller.OpenDatabase($msiPath, 0)
            $view = $database.OpenView("SELECT Property, Value FROM Property")
            $view.Execute()
            
            Write-Host "Available MSI properties:" -ForegroundColor Gray
            $record = $view.Fetch()
            while ($record -ne $null) {
                $prop = $record.StringData(1)
                $val = $record.StringData(2)
                if ($prop -match "INSTALL|ADD|REMOVE|FEATURE") {
                    Write-Host "  $prop = $val" -ForegroundColor Gray
                }
                $record = $view.Fetch()
            }
        }
        catch {
            Write-Host "Could not read MSI properties: $_" -ForegroundColor Yellow
        }
        
        # Clean up
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $false
            Method = "All methods failed"
            ExitCode = $process3.ExitCode
        }
    }
    
    # Display results
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RESULT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($result.Success) {
        Write-Host "Node.js installation SUCCESSFUL!" -ForegroundColor Green
        Write-Host "Method: $($result.Method)" -ForegroundColor Green
        Write-Host "Version: $($result.Version)" -ForegroundColor Green
    }
    else {
        Write-Host "Node.js installation FAILED" -ForegroundColor Red
        Write-Host "Exit Code: $($result.ExitCode)" -ForegroundColor Red
        
        # Common MSI error codes
        switch ($result.ExitCode) {
            1603 { Write-Host "Error 1603: Fatal error during installation" -ForegroundColor Red }
            1619 { Write-Host "Error 1619: Installation package could not be opened" -ForegroundColor Red }
            1625 { Write-Host "Error 1625: Installation forbidden by system policy" -ForegroundColor Red }
            3010 { Write-Host "Error 3010: Restart required" -ForegroundColor Yellow }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}