# Get detailed SetupLab results from remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Getting SetupLab results from $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $info = @{}
        
        # Check latest SetupLab summary
        $summaryPath = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $summaryPath) {
            $latestSummary = Get-ChildItem "$summaryPath\SetupSummary_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestSummary) {
                $info.SummaryContent = Get-Content $latestSummary.FullName -Raw
            }
        }
        
        # Check if install-claude-cli.ps1 exists in temp
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort-Object LastWriteTime -Descending
        if ($tempFolders) {
            $latestTemp = $tempFolders[0]
            $claudeScript = Join-Path $latestTemp.FullName "install-claude-cli.ps1"
            if (Test-Path $claudeScript) {
                # Check if it has our fix
                $content = Get-Content $claudeScript -Raw
                $info.ClaudeScriptHasFix = $content -match 'if \(-not \$currentPath\)'
                
                # Get first 20 lines around the fix
                $lines = Get-Content $claudeScript
                $info.ClaudeScriptSnippet = $lines[45..55] -join "`n"
            }
        }
        
        # Check Claude CLI and npm
        $info.ClaudeExists = Test-Path "C:\Users\administrator\AppData\Roaming\npm\claude.cmd"
        
        # Check npm in PATH
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $info.NodeInMachinePath = $machinePath -like "*nodejs*"
        $info.NpmInUserPath = $userPath -like "*npm*"
        
        # Test npm directly
        try {
            $npmTest = & cmd /c "C:\Program Files\nodejs\npm.cmd --version 2>&1"
            $info.NpmDirectTest = $npmTest
        } catch {
            $info.NpmDirectTest = "Failed: $_"
        }
        
        return $info
    }
    
    # Display results
    if ($results.SummaryContent) {
        Write-Host "`nSetupLab Summary:" -ForegroundColor Cyan
        Write-Host $results.SummaryContent
    }
    
    Write-Host "`n`nClaude CLI Script Analysis:" -ForegroundColor Yellow
    Write-Host "  Script has fix: $($results.ClaudeScriptHasFix)"
    if ($results.ClaudeScriptSnippet) {
        Write-Host "  Script snippet (lines 46-56):" -ForegroundColor Gray
        $results.ClaudeScriptSnippet -split "`n" | ForEach-Object { Write-Host "    $_" }
    }
    
    Write-Host "`n`nEnvironment Status:" -ForegroundColor Yellow
    Write-Host "  Claude CLI exists: $($results.ClaudeExists)"
    Write-Host "  Node.js in Machine PATH: $($results.NodeInMachinePath)"
    Write-Host "  NPM in User PATH: $($results.NpmInUserPath)"
    Write-Host "  NPM direct test: $($results.NpmDirectTest)"
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}