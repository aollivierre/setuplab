# Move old installer scripts to Archive folder
$rootPath = "C:\Code\setuplab"
$archivePath = Join-Path $rootPath "Archive"

# Ensure Archive folder exists
if (-not (Test-Path $archivePath)) {
    Write-Host "Creating Archive folder..."
    New-Item -Path $archivePath -ItemType Directory -Force
}

# Move all Install-*.ps1 files
Write-Host "Moving Install-*.ps1 files to Archive folder..."
$installScripts = Get-ChildItem -Path $rootPath -Filter "Install-*.ps1"
foreach ($script in $installScripts) {
    $destination = Join-Path $archivePath $script.Name
    Write-Host "Moving $($script.Name) to Archive..."
    Move-Item -Path $script.FullName -Destination $destination -Force
}

# Move setup.ps1
$setupScript = Join-Path $rootPath "setup.ps1"
if (Test-Path $setupScript) {
    Write-Host "Moving setup.ps1 to Archive..."
    $destination = Join-Path $archivePath "setup.ps1"
    Move-Item -Path $setupScript -Destination $destination -Force
}

Write-Host "`nMove operation completed successfully!"
Write-Host "Files moved to: $archivePath"