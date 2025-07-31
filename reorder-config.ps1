# Reorder software-config.json to move PowerShell 7 to the end
$config = Get-Content "C:\code\setuplab\software-config.json" -Raw | ConvertFrom-Json

# Find PowerShell 7 entry
$ps7 = $config.software | Where-Object { $_.name -eq "PowerShell 7" }

if ($ps7) {
    # Remove PowerShell 7 from its current position
    $newSoftware = $config.software | Where-Object { $_.name -ne "PowerShell 7" }
    
    # Add PowerShell 7 at the end
    $config.software = @($newSoftware) + $ps7
    
    # Save the reordered config
    $config | ConvertTo-Json -Depth 10 | Set-Content "C:\code\setuplab\software-config.json" -Encoding UTF8
    
    Write-Host "Reordered software-config.json - PowerShell 7 moved to end" -ForegroundColor Green
    
    # Show new order
    Write-Host "`nNew installation order:" -ForegroundColor Cyan
    $i = 1
    foreach ($app in $config.software) {
        Write-Host "$i. $($app.name)" -ForegroundColor Gray
        $i++
    }
} else {
    Write-Host "PowerShell 7 not found in config" -ForegroundColor Red
}