# Check SetupLab logs on remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Checking SetupLab logs on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logs = Invoke-Command -Session $session -ScriptBlock {
        # Get latest temp folder
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort-Object LastWriteTime -Descending
        if ($tempFolders) {
            $latestFolder = $tempFolders[0]
            $logPath = Join-Path $latestFolder.FullName "Logs"
            
            if (Test-Path $logPath) {
                $summaryFile = Get-ChildItem "$logPath\SetupSummary_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($summaryFile) {
                    $content = Get-Content $summaryFile.FullName -Raw
                    return @{
                        Found = $true
                        Path = $summaryFile.FullName
                        Content = $content
                    }
                }
            }
        }
        
        return @{Found = $false}
    }
    
    if ($logs.Found) {
        Write-Host "`nFound log at: $($logs.Path)" -ForegroundColor Green
        Write-Host "`nLog content:" -ForegroundColor Cyan
        Write-Host $logs.Content
    } else {
        Write-Host "No logs found yet" -ForegroundColor Yellow
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}