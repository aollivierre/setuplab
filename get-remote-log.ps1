# Get the full log from remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Get the latest log file
    $logContent = Invoke-Command -Session $session -ScriptBlock {
        $logPath = "C:\SetupLab\Logs"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem -Path $logPath -Filter "SetupLab_*.log" | 
                         Sort-Object LastWriteTime -Descending | 
                         Select-Object -First 1
            if ($latestLog) {
                Get-Content $latestLog.FullName
            }
        }
    }
    
    if ($logContent) {
        $outputFile = "C:\code\setuplab\remote-installation.log"
        $logContent | Out-File -FilePath $outputFile -Encoding UTF8
        Write-Host "Log saved to: $outputFile" -ForegroundColor Green
        
        # Show summary of errors
        $errors = $logContent | Where-Object { $_ -match '\[Error\]' }
        Write-Host "`nFound $($errors.Count) errors in log:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host $_ -ForegroundColor DarkRed }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}