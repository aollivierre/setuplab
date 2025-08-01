# Read c:\code\log.txt from remote machine
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Reading c:\code\log.txt from $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $logContent = Invoke-Command -Session $session -ScriptBlock {
        if (Test-Path "C:\code\log.txt") {
            Get-Content "C:\code\log.txt" -Raw
        } else {
            "Log file not found at C:\code\log.txt"
        }
    }
    
    Write-Host "`nLog content:" -ForegroundColor Cyan
    Write-Host $logContent
    
    # Save to local file for analysis
    $logContent | Out-File -FilePath "C:\code\setuplab\remote-log-analysis.txt" -Encoding UTF8
    Write-Host "`nLog saved to: C:\code\setuplab\remote-log-analysis.txt" -ForegroundColor Green
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}