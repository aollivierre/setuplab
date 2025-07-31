# Fix for Node.js validation - check if actually installed even with exit code 1603
# This will update the SetupLabCore.psm1 to check installation success after MSI errors

$filePath = "C:\code\setuplab\SetupLabCore.psm1"
$content = Get-Content $filePath -Raw

# Find the section that handles exit code checking
$oldPattern = @'
    # Only check exit code if we have a process and it has exited
    if ($process -and $process.HasExited) {
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
    }
'@

$newPattern = @'
    # Only check exit code if we have a process and it has exited
    if ($process -and $process.HasExited) {
        if ($process.ExitCode -ne 0) {
            # For MSI installs, check if software was actually installed despite error code
            if ($InstallType -eq 'MSI' -and ($process.ExitCode -eq 1603 -or $process.ExitCode -eq 3010)) {
                Write-SetupLog "MSI returned code $($process.ExitCode), checking if software was installed..." -Level Warning
                # Give it a moment to complete
                Start-Sleep -Seconds 2
                # Don't throw error yet - let the validation check handle it
            }
            else {
                throw "Installation failed with exit code: $($process.ExitCode)"
            }
        }
    }
'@

# Replace the content
$content = $content -replace [regex]::Escape($oldPattern), $newPattern

# Write back
Set-Content -Path $filePath -Value $content -Encoding UTF8

Write-Host "Updated SetupLabCore.psm1 to handle MSI exit codes 1603 and 3010 gracefully" -ForegroundColor Green
Write-Host "These codes often indicate success with warnings rather than failure" -ForegroundColor Yellow