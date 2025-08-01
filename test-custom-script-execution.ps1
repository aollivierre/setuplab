# Test CUSTOM script execution exactly as SetupLabCore does it
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Testing CUSTOM script execution on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Set execution policy like the web launcher does
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        
        # Download the script
        $scriptUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
        $tempDir = "$env:TEMP\SetupLab_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        $scriptPath = Join-Path $tempDir "install-claude-cli.ps1"
        Write-Host "Downloading to: $scriptPath" -ForegroundColor Gray
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        
        # Mimic SetupLabCore's CUSTOM execution
        Write-Host "`nMimicking SetupLabCore CUSTOM execution..." -ForegroundColor Cyan
        
        try {
            # This is exactly how SetupLabCore executes CUSTOM scripts
            $scriptDir = Split-Path $scriptPath -Parent
            Write-Host "Script Directory: $scriptDir" -ForegroundColor Gray
            Push-Location $scriptDir
            
            try {
                Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Gray
                Write-Host "Executing: & `"$scriptPath`"" -ForegroundColor Yellow
                
                # Capture both output and error
                $output = & $scriptPath 2>&1
                
                Write-Host "`nScript Output:" -ForegroundColor Green
                $output | ForEach-Object { Write-Host $_ }
                
            } finally {
                Pop-Location
            }
        } catch {
            Write-Host "`nERROR in CUSTOM execution:" -ForegroundColor Red
            Write-Host "Message: $_" -ForegroundColor Red
            Write-Host "Exception: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            
            # Check if it's the PATH error
            if ($_ -match "Cannot bind argument to parameter 'Path'") {
                Write-Host "`nThis is THE error we're looking for!" -ForegroundColor Magenta
                Write-Host "Let's trace where it comes from..." -ForegroundColor Yellow
                
                # Get the script content and find lines with Path parameter
                $scriptContent = Get-Content $scriptPath
                $lineNum = 0
                $scriptContent | ForEach-Object {
                    $lineNum++
                    if ($_ -match "-Path|Path =|'Path'") {
                        Write-Host "Line ${lineNum}: $_" -ForegroundColor Cyan
                    }
                }
            }
        }
        
        # Check if Claude CLI was installed
        $claudePath = "$env:APPDATA\npm\claude.cmd"
        $installed = Test-Path $claudePath
        Write-Host "`nClaude CLI installed: $installed" -ForegroundColor $(if($installed){'Green'}else{'Red'})
        
        return $installed
    }
    
    Write-Host "`nTest Result: $(if($result){'SUCCESS'}else{'FAILED'})" -ForegroundColor $(if($result){'Green'}else{'Red'})
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}