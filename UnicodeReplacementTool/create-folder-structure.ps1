# Create folder structure for Unicode Replacement Tool

$baseDir = "C:\code\UnicodeReplacementTool"

# Create subdirectories
$folders = @(
    "Config",
    "Scripts",
    "Tests",
    "Samples",
    "Backups",
    "Logs"
)

foreach ($folder in $folders) {
    $path = Join-Path $baseDir $folder
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "[SUCCESS] Created folder: $path" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Folder already exists: $path" -ForegroundColor Yellow
    }
}

Write-Host "`n[SUCCESS] Folder structure created successfully!" -ForegroundColor Green