# Find SetupLab summary
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Finding SetupLab summary files..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Invoke-Command -Session $session -ScriptBlock {
        # Search in multiple locations
        $searchPaths = @(
            "C:\ProgramData\SetupLab\Logs\*.txt",
            "$env:TEMP\SetupLab_*\Logs\*.txt",
            "$env:TEMP\SetupLab_*\*.log"
        )
        
        foreach ($searchPath in $searchPaths) {
            Write-Host "`nSearching: $searchPath" -ForegroundColor Gray
            $files = Get-ChildItem $searchPath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
            
            foreach ($file in $files) {
                Write-Host "`nFile: $($file.FullName)" -ForegroundColor Cyan
                Write-Host "Size: $($file.Length) bytes" -ForegroundColor Gray
                Write-Host "Modified: $($file.LastWriteTime)" -ForegroundColor Gray
                
                # Look for Claude or summary info
                $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
                
                # Check if this is a summary
                if ($content -match "Installation Summary") {
                    Write-Host "FOUND SUMMARY FILE!" -ForegroundColor Green
                    $summary = $content | Where-Object { $_ -match "Summary|Completed|Failed|Claude" }
                    $summary | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                }
                
                # Check for Claude error
                $claudeError = $content | Where-Object { $_ -match "Failed to install Claude|Claude.*Error" }
                if ($claudeError) {
                    Write-Host "`nCLAUDE ERROR FOUND:" -ForegroundColor Red
                    $claudeError | ForEach-Object { Write-Host $_ -ForegroundColor Red }
                }
            }
        }
        
        # Direct check for running processes
        Write-Host "`n`nCurrent Status:" -ForegroundColor Cyan
        Write-Host "PowerShell processes: $((Get-Process powershell*).Count)" -ForegroundColor Gray
        Write-Host "Installer processes: $((Get-Process | Where-Object { $_.Name -match 'msiexec|setup' }).Count)" -ForegroundColor Gray
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}