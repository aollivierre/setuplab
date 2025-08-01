# Archive temporary files
New-Item -Path "archive\temp-files" -ItemType Directory -Force | Out-Null
Move-Item -Path "commit-msg.ps1", "create-commit.ps1" -Destination "archive\temp-files\" -Force
Write-Host "Files archived to archive\temp-files\"