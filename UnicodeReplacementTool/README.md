# Unicode Replacement Tool for PowerShell

A comprehensive tool to detect and replace Unicode characters in PowerShell scripts that cause compatibility issues with PowerShell 5.1.

## Problem

PowerShell 5.1 doesn't handle Unicode characters well, causing scripts to fail with parsing errors. Common problematic characters include:
- Checkmarks, crosses, warning signs
- Arrows, special quotes, mathematical symbols  
- Emojis and other decorative characters

## Solution

This tool automatically finds and replaces Unicode characters with ASCII-safe alternatives:
- ✓ → [OK]
- ✗ → [FAIL]
- ⚠ → [WARNING]
- → → ->
- And many more...

## Quick Start

```powershell
# Preview changes in current directory
.\Quick-ReplaceUnicode.ps1 -PreviewOnly

# Fix all scripts in current directory
.\Quick-ReplaceUnicode.ps1

# Fix recursively
.\Quick-ReplaceUnicode.ps1 -Recurse
```

## Full Usage

```powershell
# Preview changes
.\Replace-UnicodeInScripts.ps1 -Path "C:\Scripts" -PreviewOnly

# Process single file
.\Replace-UnicodeInScripts.ps1 -Path "C:\Scripts\broken.ps1"

# Process directory recursively
.\Replace-UnicodeInScripts.ps1 -Path "C:\MyProject" -Recurse

# Skip backups (use with caution!)
.\Replace-UnicodeInScripts.ps1 -Path "C:\Scripts" -NoBackup
```

## Features

- **Safe by default**: Creates backups before modifying files
- **Preview mode**: See what would be changed without modifying files
- **Comprehensive mappings**: 50+ Unicode character replacements
- **Batch processing**: Handle entire directories
- **Detailed logging**: Track all changes made
- **Extensible**: Easy to add new Unicode mappings

## Directory Structure

```
UnicodeReplacementTool/
├── Config/
│   └── UnicodeReplacements.json    # Unicode to ASCII mappings
├── Scripts/
│   └── UnicodeReplacementFunctions.ps1  # Core functions
├── Tests/
│   └── Test-UnicodeReplacement.ps1      # Test suite
├── Samples/
│   └── Sample-WithUnicode.txt           # Sample file with Unicode
├── Backups/                             # Auto-created backup directory
├── Logs/                                # Processing logs
├── Replace-UnicodeInScripts.ps1         # Main script
├── Quick-ReplaceUnicode.ps1             # Quick-start wrapper
├── Add-UnicodeMapping.ps1               # Add new mappings
└── Demo-FixBrokenScript.ps1             # Interactive demo

```

## Adding New Mappings

```powershell
# Add a new Unicode character mapping
.\Add-UnicodeMapping.ps1 -UnicodeChar "♥" -Replacement "[HEART]" -Category "symbols"
```

## Testing

```powershell
# Run the test suite
.\Tests\Test-UnicodeReplacement.ps1

# Run the demo
.\Demo-FixBrokenScript.ps1
```

## Safety Features

1. **Backups**: All modified files are backed up with timestamp
2. **Preview Mode**: See changes before applying them
3. **Selective Processing**: Only processes PowerShell files by default
4. **Detailed Logging**: All operations are logged with timestamps
5. **Non-destructive**: Original formatting preserved where possible

## Common Use Cases

1. **Fix AI-generated scripts**: When AI tools insert Unicode characters
2. **Clean up copied code**: From web pages or documentation  
3. **Prepare for PowerShell 5.1**: Ensure compatibility
4. **Batch cleanup**: Process entire codebases

## Notes

- The tool processes .ps1, .psm1, and .psd1 files by default
- Custom file patterns can be specified with -Include/-Exclude
- Backups are stored in the Backups folder with timestamps
- Logs provide detailed information about all replacements

## License

This tool is provided as-is for fixing Unicode issues in PowerShell scripts.