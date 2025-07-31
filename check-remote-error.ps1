# Check remote machine for web launcher error
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator",
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "CHECKING REMOTE MACHINE FOR ERRORS" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $results = Invoke-Command -Session $session -ScriptBlock {
        $info = @{}
        
        # Check C:\code folder
        Write-Host "`n[1] Checking C:\code folder..." -ForegroundColor Yellow
        if (Test-Path "C:\code") {
            $info['CodeFolderExists'] = $true
            $contents = Get-ChildItem -Path "C:\code" -ErrorAction SilentlyContinue
            $info['CodeContents'] = $contents | Select-Object Name, Length, LastWriteTime
            Write-Host "Found $(($contents | Measure-Object).Count) items in C:\code" -ForegroundColor Cyan
            
            # Look for error logs
            $errorFiles = $contents | Where-Object { $_.Name -like "*error*" -or $_.Name -like "*log*" }
            if ($errorFiles) {
                Write-Host "`nFound error/log files:" -ForegroundColor Yellow
                foreach ($file in $errorFiles) {
                    Write-Host "  - $($file.Name)" -ForegroundColor Gray
                    if ($file.Length -lt 10KB) {
                        Write-Host "    Content:" -ForegroundColor DarkGray
                        Get-Content "C:\code\$($file.Name)" -Tail 20 | ForEach-Object {
                            Write-Host "    $_" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        } else {
            $info['CodeFolderExists'] = $false
            Write-Host "C:\code folder does not exist" -ForegroundColor Red
        }
        
        # Check SetupLab folder
        Write-Host "`n[2] Checking C:\SetupLab folder..." -ForegroundColor Yellow
        if (Test-Path "C:\SetupLab") {
            $setupContents = Get-ChildItem -Path "C:\SetupLab" -ErrorAction SilentlyContinue
            $info['SetupLabContents'] = $setupContents | Select-Object Name, Length, LastWriteTime
            Write-Host "Found $(($setupContents | Measure-Object).Count) items in C:\SetupLab" -ForegroundColor Cyan
        }
        
        # Check ProgramData logs
        Write-Host "`n[3] Checking SetupLab logs..." -ForegroundColor Yellow
        $logPath = "C:\ProgramData\SetupLab\Logs"
        if (Test-Path $logPath) {
            $logs = Get-ChildItem -Path $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
            if ($logs) {
                Write-Host "Recent log files:" -ForegroundColor Cyan
                foreach ($log in $logs) {
                    Write-Host "  - $($log.Name) ($('{0:N2}' -f ($log.Length/1KB))KB)" -ForegroundColor Gray
                    
                    # Show last 30 lines of most recent log
                    if ($log -eq $logs[0]) {
                        Write-Host "`n    Last 30 lines of $($log.Name):" -ForegroundColor Yellow
                        Get-Content $log.FullName -Tail 30 | ForEach-Object {
                            if ($_ -match '\[Error\]') {
                                Write-Host "    $_" -ForegroundColor Red
                            } elseif ($_ -match '\[Warning\]') {
                                Write-Host "    $_" -ForegroundColor Yellow
                            } else {
                                Write-Host "    $_" -ForegroundColor Gray
                            }
                        }
                    }
                }
            }
        }
        
        # Check for any PowerShell errors in event log
        Write-Host "`n[4] Checking recent PowerShell errors..." -ForegroundColor Yellow
        try {
            $psErrors = Get-EventLog -LogName "Windows PowerShell" -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
            if ($psErrors) {
                Write-Host "Recent PowerShell errors:" -ForegroundColor Red
                $psErrors | Select-Object -First 3 | ForEach-Object {
                    Write-Host "`n  Time: $($_.TimeGenerated)" -ForegroundColor Yellow
                    Write-Host "  Message: $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))..." -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "Could not read event log" -ForegroundColor DarkGray
        }
        
        # Check temp folder for any SetupLab files
        Write-Host "`n[5] Checking temp folder..." -ForegroundColor Yellow
        $tempFiles = Get-ChildItem -Path "$env:TEMP" -Filter "*SetupLab*" -ErrorAction SilentlyContinue
        if ($tempFiles) {
            Write-Host "Found SetupLab files in temp:" -ForegroundColor Cyan
            $tempFiles | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor Gray
            }
        }
        
        return $info
    }
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "SUMMARY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    if ($results.CodeFolderExists) {
        Write-Host "C:\code folder exists with $($results.CodeContents.Count) items" -ForegroundColor Cyan
        if ($results.CodeContents) {
            Write-Host "`nContents:" -ForegroundColor Gray
            $results.CodeContents | ForEach-Object {
                Write-Host "  - $($_.Name) ($('{0:N2}' -f ($_.Length/1KB))KB)" -ForegroundColor Gray
            }
        }
    }
    
    Remove-PSSession $session
}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    if ($session) {
        Remove-PSSession $session -ErrorAction SilentlyContinue
    }
}