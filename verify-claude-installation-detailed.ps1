# Verify Claude installation in detail
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Verifying Claude installation on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Check various possible locations
        $checks = @{
            "APPDATA\npm\claude.cmd" = "$env:APPDATA\npm\claude.cmd"
            "APPDATA\npm\claude" = "$env:APPDATA\npm\claude"
            "ProgramFiles\nodejs\claude.cmd" = "$env:ProgramFiles\nodejs\claude.cmd"
            "npm global prefix" = (npm config get prefix 2>$null)
            "npm bin" = (npm bin -g 2>$null)
            "where claude" = (where.exe claude 2>$null)
            "Environment PATH check" = [Environment]::GetEnvironmentVariable("Path", "User") -match "npm"
        }
        
        $results = @{}
        foreach ($key in $checks.Keys) {
            $path = $checks[$key]
            if ($key -like "*\*") {
                $results[$key] = @{
                    Path = $path
                    Exists = Test-Path $path
                }
            } else {
                $results[$key] = $path
            }
        }
        
        # Test path expansion
        $testPath = "%APPDATA%\npm\claude.cmd"
        $expanded = [System.Environment]::ExpandEnvironmentVariables($testPath)
        $results["Path Expansion Test"] = @{
            Original = $testPath
            Expanded = $expanded
            Exists = Test-Path $expanded
        }
        
        # Check npm packages
        $npmList = npm list -g @anthropic-ai/claude-code 2>$null
        $results["NPM Package"] = if ($npmList -match "claude-code") { "Installed" } else { "Not found" }
        
        return $results
    }
    
    Write-Host "`nClaude Installation Check Results:" -ForegroundColor Cyan
    foreach ($key in $result.Keys | Sort-Object) {
        $value = $result[$key]
        if ($value -is [hashtable]) {
            Write-Host "${key}:" -ForegroundColor Yellow
            foreach ($subkey in $value.Keys) {
                Write-Host "  ${subkey}: $($value[$subkey])" -ForegroundColor Gray
            }
        } else {
            Write-Host "${key}: $value" -ForegroundColor Gray
        }
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}