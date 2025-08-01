<#
.SYNOPSIS
    Replace Unicode characters in PowerShell scripts with ASCII-safe alternatives
.DESCRIPTION
    This tool scans PowerShell scripts for Unicode characters that may cause
    compatibility issues with PowerShell 5.1 and replaces them with ASCII-safe
    equivalents based on a configurable mapping.
.PARAMETER Path
    The file or directory path to process
.PARAMETER Recurse
    Process subdirectories recursively
.PARAMETER PreviewOnly
    Show what would be changed without making actual changes
.PARAMETER NoBackup
    Skip creating backup files (use with caution)
.PARAMETER Include
    File patterns to include (default: *.ps1, *.psm1, *.psd1)
.PARAMETER Exclude
    File patterns to exclude
.PARAMETER ConfigPath
    Path to custom Unicode replacement configuration file
.EXAMPLE
    .\Replace-UnicodeInScripts.ps1 -Path "C:\Scripts" -PreviewOnly
    Preview Unicode replacements in all scripts in C:\Scripts
.EXAMPLE
    .\Replace-UnicodeInScripts.ps1 -Path "C:\MyProject" -Recurse
    Replace Unicode characters in all scripts recursively with backups
.NOTES
    Author: Unicode Replacement Tool
    Version: 1.0.0
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    
    [switch]$Recurse,
    
    [switch]$PreviewOnly,
    
    [switch]$NoBackup,
    
    [string[]]$Include = @("*.ps1", "*.psm1", "*.psd1"),
    
    [string[]]$Exclude = @(),
    
    [string]$ConfigPath
)

#region Initialize
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot

# Import functions module
$modulePath = Join-Path $scriptDir "Scripts\UnicodeReplacementFunctions.ps1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Functions module not found at: $modulePath"
    exit 1
}

. $modulePath

# Set up logging
$logDir = Join-Path $scriptDir "Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logDir "UnicodeReplacement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "INFO" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}
#endregion

#region Main Processing
try {
    Write-Log "="*70
    Write-Log "Unicode Replacement Tool Started" "INFO"
    Write-Log "="*70
    Write-Log "Path: $Path"
    Write-Log "Preview Only: $PreviewOnly"
    Write-Log "Recurse: $Recurse"
    Write-Log "No Backup: $NoBackup"
    
    # Validate path
    if (-not (Test-Path $Path)) {
        throw "Path not found: $Path"
    }
    
    $isDirectory = (Get-Item $Path).PSIsContainer
    
    if ($PreviewOnly) {
        Write-Log "`n[PREVIEW MODE] No files will be modified" "WARNING"
    }
    
    if ($NoBackup -and -not $PreviewOnly) {
        Write-Log "`n[WARNING] Running without backups - changes cannot be undone!" "WARNING"
        
        if (-not $PSCmdlet.ShouldProcess("Run without backups", "Confirm")) {
            Write-Log "Operation cancelled by user" "INFO"
            exit 0
        }
    }
    
    # Process based on path type
    if ($isDirectory) {
        Write-Log "`nProcessing directory: $Path" "INFO"
        
        $results = Process-ScriptDirectory `
            -DirectoryPath $Path `
            -Include $Include `
            -Exclude $Exclude `
            -Recurse:$Recurse `
            -PreviewOnly:$PreviewOnly `
            -Force:$NoBackup
    }
    else {
        Write-Log "`nProcessing file: $Path" "INFO"
        
        # Check if file matches include pattern
        $fileName = [System.IO.Path]::GetFileName($Path)
        $matchesInclude = $false
        
        foreach ($pattern in $Include) {
            if ($fileName -like $pattern) {
                $matchesInclude = $true
                break
            }
        }
        
        if (-not $matchesInclude) {
            Write-Log "File does not match include patterns: $fileName" "WARNING"
            exit 0
        }
        
        $result = Process-ScriptFile `
            -FilePath $Path `
            -PreviewOnly:$PreviewOnly `
            -Force:$NoBackup
            
        $results = @($result)
    }
    
    # Generate report
    Write-Log "`n" + "="*70
    Write-Log "PROCESSING COMPLETE" "SUCCESS"
    Write-Log "="*70
    
    $modifiedFiles = $results | Where-Object { $_.Status -eq 'Modified' }
    $errorFiles = $results | Where-Object { $_.Status -eq 'Error' }
    $totalReplacements = ($results | Measure-Object -Property ReplacementCount -Sum).Sum
    
    Write-Log "Total files scanned: $($results.Count)" "INFO"
    Write-Log "Files modified: $($modifiedFiles.Count)" "INFO"
    Write-Log "Files with errors: $($errorFiles.Count)" "INFO"
    Write-Log "Total replacements: $totalReplacements" "INFO"
    
    if ($errorFiles.Count -gt 0) {
        Write-Log "`nFiles with errors:" "ERROR"
        foreach ($errorFile in $errorFiles) {
            Write-Log "  - $($errorFile.FilePath): $($errorFile.Error)" "ERROR"
        }
    }
    
    # Save detailed report
    $reportPath = Join-Path $logDir "UnicodeReplacement_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Log "`nDetailed report saved to: $reportPath" "INFO"
    
    Write-Log "`nLog file: $logFile" "INFO"
}
catch {
    Write-Log "FATAL ERROR: $_" "ERROR"
    Write-Log $_.Exception.StackTrace "ERROR"
    exit 1
}
#endregion