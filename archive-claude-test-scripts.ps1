# Archive Claude CLI test scripts
$scripts = @(
    "test-claude-cli-remote.ps1",
    "test-claude-cli-only-remote.ps1", 
    "test-claude-cli-final-remote.ps1",
    "test-connectivity.ps1",
    "fix-npm-path-remote.ps1"
)

foreach ($script in $scripts) {
    if (Test-Path $script) {
        Move-Item -Path $script -Destination "archive\debug-scripts\" -Force
        Write-Host "Archived: $script"
    }
}

Write-Host "`nTest scripts archived to archive\debug-scripts"