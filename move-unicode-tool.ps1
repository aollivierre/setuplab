# Move Unicode tool into the git repository
$source = "C:\code\UnicodeReplacementTool"
$destination = "C:\code\setuplab\UnicodeReplacementTool"

if (Test-Path $source) {
    Move-Item -Path $source -Destination $destination -Force
    Write-Host "[SUCCESS] Moved Unicode tool to: $destination" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Source directory not found: $source" -ForegroundColor Red
}