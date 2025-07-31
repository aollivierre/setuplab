# Cleanup stuck installers and retry installation
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Cleaning up stuck installers on remote machine..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # Cleanup stuck processes
    Invoke-Command -Session $session -ScriptBlock {
        # Kill stuck MSI processes
        $msiProcesses = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue
        if ($msiProcesses) {
            Write-Host "Killing $($msiProcesses.Count) stuck msiexec processes..." -ForegroundColor Red
            $msiProcesses | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
        
        # Kill any setup processes
        Get-Process -Name "*setup*", "*installer*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Clean temp files
        $tempFiles = Get-ChildItem -Path $env:TEMP -Filter "*installer*" -ErrorAction SilentlyContinue
        if ($tempFiles) {
            Write-Host "Cleaning $($tempFiles.Count) temp installer files..." -ForegroundColor Yellow
            $tempFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "Cleanup completed" -ForegroundColor Green
    }
    
    Write-Host "`nRestarting Windows Installer service..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Restart-Service msiserver -Force
        Write-Host "Windows Installer service restarted" -ForegroundColor Green
    }
    
    Remove-PSSession -Session $session
    Write-Host "`nCleanup completed. Ready to retry installation." -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}