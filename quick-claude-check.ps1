# Quick Claude CLI check
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

$session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop

$result = Invoke-Command -Session $session -ScriptBlock {
    $claudePath = "$env:APPDATA\npm\claude.cmd"
    $exists = Test-Path $claudePath
    $version = if ($exists) { cmd /c "`"$claudePath`" --version 2>&1" } else { "Not found" }
    
    "$exists|$version"
}

$parts = $result -split '\|'
Write-Host "Claude CLI exists: $($parts[0])" -ForegroundColor $(if($parts[0] -eq 'True'){'Green'}else{'Red'})
Write-Host "Version: $($parts[1])" -ForegroundColor Cyan

Remove-PSSession -Session $session