# Test what parameters are being passed to custom installer
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Testing custom installer context on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    $result = Invoke-Command -Session $session -ScriptBlock {
        # Find SetupLabCore.psm1
        $tempFolders = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort-Object LastWriteTime -Descending
        if ($tempFolders) {
            $latestTemp = $tempFolders[0]
            $corePath = Join-Path $latestTemp.FullName "SetupLabCore.psm1"
            
            if (Test-Path $corePath) {
                # Check the Invoke-SetupInstaller function
                $content = Get-Content $corePath -Raw
                
                # Look for how CUSTOM installers are called
                $customSection = $content | Select-String -Pattern "CUSTOM.*\{[\s\S]*?\}" -AllMatches
                
                return @{
                    Found = $true
                    CustomHandling = $customSection.Matches[0].Value
                }
            }
        }
        
        return @{Found = $false}
    }
    
    if ($result.Found) {
        Write-Host "`nCustom installer handling in SetupLabCore:" -ForegroundColor Cyan
        Write-Host $result.CustomHandling
    }
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}