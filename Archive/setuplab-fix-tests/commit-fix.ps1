$message = @"
Fix SetupLabCore.psm1 CUSTOM installer empty string bug

- Fixed line 1111 where Get-Module could return null causing empty scriptPath
- Added null check for module before accessing .Path property
- Added fallback to current directory if module not loaded
- Updated WebLauncher version to 2.1.0 to track this fix
- This fixes the "Cannot bind argument to parameter Path because it is an empty string" error

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@

git commit -m $message