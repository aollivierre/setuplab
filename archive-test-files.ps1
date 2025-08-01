# Archive test files
$testFiles = @(
    "SetupLabCore-EXACT-FIX.ps1",
    "SetupLabCore-Fix.ps1", 
    "commit-fix.ps1",
    "download-setuplab-core.ps1",
    "git-commit-fix.ps1",
    "test-empty-string-fix.ps1",
    "test-fixed-setuplab.ps1",
    "test-module-path-issue.ps1",
    "test-setuplab-with-fixed-module.ps1"
)

New-Item -Path "archive\setuplab-fix-tests" -ItemType Directory -Force | Out-Null

foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Move-Item -Path $file -Destination "archive\setuplab-fix-tests\" -Force
        Write-Host "Archived: $file" -ForegroundColor Gray
    }
}

Write-Host "`nFiles archived to archive\setuplab-fix-tests\" -ForegroundColor Green