# Check actual status and logs
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking actual status..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "`n1. Process Check:" -ForegroundColor Cyan
        $procs = Get-Process | Where-Object { $_.Name -match "msiexec|setup|install" }
        Write-Host "Active installers: $($procs.Count)" -ForegroundColor Gray
        
        Write-Host "`n2. SetupLab Logs:" -ForegroundColor Cyan
        $logDir = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logDir) {
            $logs = Get-ChildItem "$logDir\*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logs) {
                Write-Host "Latest log: $($logs.Name)" -ForegroundColor Gray
                Write-Host "Last modified: $($logs.LastWriteTime)" -ForegroundColor Gray
                
                # Get Claude-specific lines
                $content = Get-Content $logs.FullName
                $claudeLines = $content | Where-Object { $_ -match "Claude|install-claude" }
                
                Write-Host "`nClaude-related entries:" -ForegroundColor Yellow
                $claudeLines | Select-Object -Last 10 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                
                # Get summary
                $summary = $content | Where-Object { $_ -match "Installation Summary:|Completed:|Failed:|Setup Complete!" }
                Write-Host "`nSummary:" -ForegroundColor Yellow
                $summary | Select-Object -Last 10 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            }
        }
        
        Write-Host "`n3. Claude Status:" -ForegroundColor Cyan
        Write-Host "npm dir: $(Test-Path "$env:APPDATA\npm")" -ForegroundColor Gray
        Write-Host "claude.cmd: $(Test-Path "$env:APPDATA\npm\claude.cmd")" -ForegroundColor Gray
        
        # Check in Program Files too
        Write-Host "`n4. Other Claude locations:" -ForegroundColor Cyan
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Programs\claude",
            "$env:ProgramFiles\claude",
            "$env:APPDATA\npm\node_modules\@anthropic-ai\claude-code"
        )
        
        foreach ($path in $possiblePaths) {
            Write-Host "$path : $(Test-Path $path)" -ForegroundColor Gray
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}