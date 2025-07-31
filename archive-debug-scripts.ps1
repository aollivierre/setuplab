# Archive debug scripts
$archivePath = "C:\code\setuplab\archive\debug-scripts"

# Create archive directory if it doesn't exist
if (-not (Test-Path $archivePath)) {
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    Write-Host "Created archive directory: $archivePath"
}

# Move debug scripts to archive
$scriptsToArchive = @(
    "C:\code\setuplab\check-quotes.ps1",
    "C:\code\setuplab\find-all-smart-quotes.ps1", 
    "C:\code\setuplab\check-line-100.ps1"
)

foreach ($script in $scriptsToArchive) {
    if (Test-Path $script) {
        $fileName = Split-Path $script -Leaf
        Move-Item -Path $script -Destination (Join-Path $archivePath $fileName) -Force
        Write-Host "Archived: $fileName"
    }
}

Write-Host "`nDebug scripts archived to: $archivePath"