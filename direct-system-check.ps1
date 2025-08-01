# Direct system check
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Direct system check..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "`n1. System Info:" -ForegroundColor Cyan
        Write-Host "Current Time: $(Get-Date)" -ForegroundColor Gray
        Write-Host "Username: $env:USERNAME" -ForegroundColor Gray
        Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Gray
        
        Write-Host "`n2. Check installed programs:" -ForegroundColor Cyan
        $programs = @(
            @{Name="Node.js"; Path="C:\Program Files\nodejs\node.exe"},
            @{Name="Git"; Path="C:\Program Files\Git\bin\git.exe"},
            @{Name="VS Code"; Path="C:\Program Files\Microsoft VS Code\Code.exe"},
            @{Name="7-Zip"; Path="C:\Program Files\7-Zip\7z.exe"}
        )
        
        foreach ($prog in $programs) {
            $exists = Test-Path $prog.Path
            Write-Host "$($prog.Name): $(if($exists){'Installed'}else{'Not found'})" -ForegroundColor $(if($exists){'Green'}else{'Gray'})
        }
        
        Write-Host "`n3. npm/Claude check:" -ForegroundColor Cyan
        Write-Host "APPDATA: $env:APPDATA" -ForegroundColor Gray
        
        # Check if npm directory exists
        $npmDir = "$env:APPDATA\npm"
        Write-Host "npm directory ($npmDir): $(if(Test-Path $npmDir){'EXISTS'}else{'MISSING'})" -ForegroundColor $(if(Test-Path $npmDir){'Green'}else{'Red'})
        
        if (Test-Path $npmDir) {
            Write-Host "Contents:" -ForegroundColor Gray
            Get-ChildItem $npmDir | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        }
        
        # Check Node/npm
        Write-Host "`n4. Node/npm versions:" -ForegroundColor Cyan
        try {
            $nodeVer = & "C:\Program Files\nodejs\node.exe" --version 2>&1
            Write-Host "Node: $nodeVer" -ForegroundColor Green
        } catch {
            Write-Host "Node: Not available" -ForegroundColor Red
        }
        
        try {
            $npmVer = & "C:\Program Files\nodejs\npm.cmd" --version 2>&1
            Write-Host "npm: $npmVer" -ForegroundColor Green
        } catch {
            Write-Host "npm: Not available" -ForegroundColor Red
        }
        
        Write-Host "`n5. Active processes:" -ForegroundColor Cyan
        $procs = Get-Process | Where-Object { $_.Name -match "msiexec|setup|install|powershell" } | Select-Object Name, Id
        if ($procs) {
            $procs | ForEach-Object { Write-Host "  - $($_.Name) (PID: $($_.Id))" -ForegroundColor Gray }
        } else {
            Write-Host "  No installation processes found" -ForegroundColor Yellow
        }
        
        Write-Host "`n6. SetupLab directories:" -ForegroundColor Cyan
        $setupDirs = @(
            "C:\ProgramData\SetupLab",
            "$env:TEMP\SetupLab_*"
        )
        
        foreach ($dir in $setupDirs) {
            $found = Get-Item $dir -ErrorAction SilentlyContinue
            if ($found) {
                Write-Host "Found: $($found.FullName)" -ForegroundColor Green
                if ($found -is [array]) {
                    $found | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
                }
            }
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}