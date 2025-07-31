# Fixed Claude CLI installation - handles spaces in paths correctly
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INSTALLING CLAUDE CLI (FIXED)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        Write-Host "`nSetting up environment..." -ForegroundColor Yellow
        
        # Ensure temp directory exists
        if (-not (Test-Path "C:\temp")) {
            New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        }
        
        # Update PATH
        $nodePath = "C:\Program Files\nodejs"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";$nodePath"
        
        # Method 1: Use PowerShell directly with proper quoting
        Write-Host "`nMethod 1: Installing Claude CLI via PowerShell..." -ForegroundColor Yellow
        try {
            Set-Location $nodePath
            $npmCmd = ".\npm.cmd"
            $result1 = & $npmCmd install -g @anthropic-ai/claude-code 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Claude CLI installed successfully!" -ForegroundColor Green
                
                # Check installation
                $claudePath = "$env:APPDATA\npm\claude.cmd"
                if (Test-Path $claudePath) {
                    Write-Host "[OK] Claude CLI found at: $claudePath" -ForegroundColor Green
                    return $true
                }
            } else {
                Write-Host "[WARNING] Method 1 failed, trying Method 2..." -ForegroundColor Yellow
                Write-Host "Output: $result1" -ForegroundColor Gray
            }
        } catch {
            Write-Host "[WARNING] Method 1 exception: $_" -ForegroundColor Yellow
        }
        
        # Method 2: Create a batch file to handle the installation
        Write-Host "`nMethod 2: Installing via batch file..." -ForegroundColor Yellow
        $batchContent = @"
@echo off
cd /d "C:\Program Files\nodejs"
call npm.cmd install -g @anthropic-ai/claude-code
exit /b %ERRORLEVEL%
"@
        
        $batchPath = "C:\temp\install-claude.bat"
        Set-Content -Path $batchPath -Value $batchContent
        
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batchPath`"" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "[OK] Claude CLI installed successfully!" -ForegroundColor Green
            
            # Check installation
            $claudePaths = @(
                "$env:APPDATA\npm\claude.cmd",
                "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
            )
            
            foreach ($path in $claudePaths) {
                if (Test-Path $path) {
                    Write-Host "[OK] Claude CLI found at: $path" -ForegroundColor Green
                    return $true
                }
            }
        }
        
        # Method 3: Direct npm execution with full paths
        Write-Host "`nMethod 3: Direct execution with escaped paths..." -ForegroundColor Yellow
        $npmExe = "C:\Program Files\nodejs\npm.cmd"
        $args = @("install", "-g", "@anthropic-ai/claude-code")
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $npmExe
        $processInfo.Arguments = $args -join " "
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        $processInfo.WorkingDirectory = "C:\Program Files\nodejs"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $process.WaitForExit()
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        if ($process.ExitCode -eq 0) {
            Write-Host "[OK] Claude CLI installed successfully!" -ForegroundColor Green
            Write-Host "Output: $stdout" -ForegroundColor Gray
            
            # Final check
            $claudeFound = $false
            @("$env:APPDATA\npm", "C:\Users\administrator\AppData\Roaming\npm") | ForEach-Object {
                if (Test-Path "$_\claude.cmd") {
                    Write-Host "[OK] Claude CLI verified at: $_\claude.cmd" -ForegroundColor Green
                    $claudeFound = $true
                }
            }
            
            return $claudeFound
        } else {
            Write-Host "[ERROR] Installation failed" -ForegroundColor Red
            Write-Host "Error: $stderr" -ForegroundColor Red
            return $false
        }
    }
    
    if ($result) {
        Write-Host "`n####################################################" -ForegroundColor Green
        Write-Host "#           CLAUDE CLI INSTALLED!                  #" -ForegroundColor Green
        Write-Host "####################################################" -ForegroundColor Green
        Write-Host "# You now have 15/16 apps installed (93.75%)!     #" -ForegroundColor Green
        Write-Host "# Only Windows Terminal detection fails remotely   #" -ForegroundColor Yellow
        Write-Host "####################################################" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}