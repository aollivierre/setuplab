# Archive old installer scripts
$scriptsToArchive = @(
    "Install-*.ps1",
    "setup.ps1"
)

foreach ($pattern in $scriptsToArchive) {
    $files = Get-ChildItem -Path $PSScriptRoot -Filter $pattern -File
    
    foreach ($file in $files) {
        $destination = Join-Path $PSScriptRoot "Archive" $file.Name
        
        if (Test-Path $file.FullName) {
            Write-Host "Moving $($file.Name) to Archive folder..."
            Move-Item -Path $file.FullName -Destination $destination -Force
        }
    }
}

Write-Host "Archive complete!" -ForegroundColor Green