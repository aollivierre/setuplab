#region Module Header
<#
.SYNOPSIS
    Unicode Replacement Functions Module
.DESCRIPTION
    Provides functions for detecting and replacing Unicode characters in PowerShell scripts
    to ensure PowerShell 5.1 compatibility.
.NOTES
    Author: Unicode Replacement Tool
    Version: 1.0.0
    Compatible with: PowerShell 5.1+
#>
#endregion

#region Configuration Loading
function Get-UnicodeReplacementConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\Config\UnicodeReplacements.json"
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        return $null
    }
}
#endregion

#region Unicode Detection
function Find-UnicodeCharacters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text,
        
        [switch]$IncludeDetails
    )
    
    $unicodeChars = @()
    $charArray = $Text.ToCharArray()
    
    for ($i = 0; $i -lt $charArray.Length; $i++) {
        $char = $charArray[$i]
        $charCode = [int]$char
        
        # Check if character is outside ASCII range (0-127)
        if ($charCode -gt 127) {
            $unicodeChar = @{
                Character = $char
                CharCode = $charCode
                HexCode = "U+" + $charCode.ToString("X4")
                Position = $i
                Context = ""
            }
            
            if ($IncludeDetails) {
                # Get surrounding context (10 chars before and after)
                $start = [Math]::Max(0, $i - 10)
                $end = [Math]::Min($Text.Length - 1, $i + 10)
                $unicodeChar.Context = $Text.Substring($start, $end - $start + 1)
            }
            
            $unicodeChars += $unicodeChar
        }
    }
    
    return $unicodeChars
}
#endregion

#region Replacement Functions
function Get-ReplacementText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UnicodeChar,
        
        [hashtable]$ReplacementMap
    )
    
    if ($null -eq $ReplacementMap) {
        $config = Get-UnicodeReplacementConfig
        $ReplacementMap = @{}
        
        # Flatten all replacement categories into single hashtable
        foreach ($category in $config.replacements.PSObject.Properties) {
            foreach ($prop in $category.Value.PSObject.Properties) {
                $ReplacementMap[$prop.Name] = $prop.Value
            }
        }
    }
    
    if ($ReplacementMap.ContainsKey($UnicodeChar)) {
        return $ReplacementMap[$UnicodeChar]
    }
    
    # If no specific replacement found, return generic placeholder
    $charCode = [int][char]$UnicodeChar
    return "[U+$($charCode.ToString('X4'))]"
}

function Replace-UnicodeInText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text,
        
        [hashtable]$ReplacementMap,
        
        [switch]$PreviewOnly
    )
    
    $unicodeChars = Find-UnicodeCharacters -Text $Text -IncludeDetails
    
    if ($unicodeChars.Count -eq 0) {
        Write-Verbose "No Unicode characters found in text"
        return @{
            OriginalText = $Text
            ModifiedText = $Text
            ReplacementCount = 0
            Replacements = @()
        }
    }
    
    $modifiedText = $Text
    $replacements = @()
    
    # Process replacements in reverse order to maintain position accuracy
    $sortedChars = $unicodeChars | Sort-Object Position -Descending
    
    foreach ($unicodeInfo in $sortedChars) {
        $replacement = Get-ReplacementText -UnicodeChar $unicodeInfo.Character -ReplacementMap $ReplacementMap
        
        if (-not $PreviewOnly) {
            $modifiedText = $modifiedText.Remove($unicodeInfo.Position, 1).Insert($unicodeInfo.Position, $replacement)
        }
        
        $replacements += @{
            Original = $unicodeInfo.Character
            Replacement = $replacement
            Position = $unicodeInfo.Position
            Context = $unicodeInfo.Context
        }
    }
    
    return @{
        OriginalText = $Text
        ModifiedText = $modifiedText
        ReplacementCount = $replacements.Count
        Replacements = $replacements
    }
}
#endregion

#region File Processing
function Process-ScriptFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [string]$BackupDirectory = "$PSScriptRoot\..\Backups",
        
        [switch]$PreviewOnly,
        
        [switch]$Force
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            throw "File not found: $FilePath"
        }
        
        # Read file content
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        
        # Check for Unicode characters
        $unicodeChars = Find-UnicodeCharacters -Text $content
        
        if ($unicodeChars.Count -eq 0) {
            Write-Host "[INFO] No Unicode characters found in: $FilePath" -ForegroundColor Green
            return @{
                FilePath = $FilePath
                Status = "NoChangesNeeded"
                ReplacementCount = 0
            }
        }
        
        Write-Host "[WARNING] Found $($unicodeChars.Count) Unicode characters in: $FilePath" -ForegroundColor Yellow
        
        # Perform replacements
        $result = Replace-UnicodeInText -Text $content -PreviewOnly:$PreviewOnly
        
        if ($PreviewOnly) {
            Write-Host "[PREVIEW] Would replace $($result.ReplacementCount) characters" -ForegroundColor Cyan
            foreach ($replacement in $result.Replacements) {
                Write-Host "  $($replacement.Original) -> $($replacement.Replacement)" -ForegroundColor DarkGray
            }
            return @{
                FilePath = $FilePath
                Status = "PreviewOnly"
                ReplacementCount = $result.ReplacementCount
                Replacements = $result.Replacements
            }
        }
        
        # Create backup
        if (-not $Force) {
            $backupPath = Join-Path $BackupDirectory ("$([System.IO.Path]::GetFileName($FilePath)).backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
            
            # Ensure backup directory exists
            if (-not (Test-Path $BackupDirectory)) {
                New-Item -Path $BackupDirectory -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item -Path $FilePath -Destination $backupPath -Force
            Write-Host "[INFO] Backup created: $backupPath" -ForegroundColor Gray
        }
        
        # Write modified content
        Set-Content -Path $FilePath -Value $result.ModifiedText -Encoding UTF8 -NoNewline
        
        Write-Host "[SUCCESS] Replaced $($result.ReplacementCount) Unicode characters in: $FilePath" -ForegroundColor Green
        
        return @{
            FilePath = $FilePath
            Status = "Modified"
            ReplacementCount = $result.ReplacementCount
            BackupPath = $backupPath
            Replacements = $result.Replacements
        }
    }
    catch {
        Write-Error "Failed to process file $FilePath : $_"
        return @{
            FilePath = $FilePath
            Status = "Error"
            Error = $_.Exception.Message
        }
    }
}
#endregion

#region Batch Processing
function Process-ScriptDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath,
        
        [string[]]$Include = @("*.ps1", "*.psm1", "*.psd1"),
        
        [string[]]$Exclude = @(),
        
        [switch]$Recurse,
        
        [switch]$PreviewOnly,
        
        [switch]$Force
    )
    
    try {
        if (-not (Test-Path $DirectoryPath)) {
            throw "Directory not found: $DirectoryPath"
        }
        
        $searchParams = @{
            Path = $DirectoryPath
            Include = $Include
            Exclude = $Exclude
            File = $true
        }
        
        if ($Recurse) {
            $searchParams.Recurse = $true
        }
        
        $files = Get-ChildItem @searchParams
        
        Write-Host "`n[INFO] Found $($files.Count) files to process" -ForegroundColor Cyan
        
        $results = @()
        $totalReplacements = 0
        
        foreach ($file in $files) {
            Write-Host "`nProcessing: $($file.FullName)" -ForegroundColor White
            
            $result = Process-ScriptFile -FilePath $file.FullName -PreviewOnly:$PreviewOnly -Force:$Force
            $results += $result
            
            if ($result.ReplacementCount) {
                $totalReplacements += $result.ReplacementCount
            }
        }
        
        # Summary
        Write-Host "`n" + "="*60 -ForegroundColor DarkGray
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "Total files processed: $($files.Count)" -ForegroundColor White
        Write-Host "Files with changes: $(($results | Where-Object {$_.Status -eq 'Modified'}).Count)" -ForegroundColor White
        Write-Host "Total replacements: $totalReplacements" -ForegroundColor White
        Write-Host "="*60 + "`n" -ForegroundColor DarkGray
        
        return $results
    }
    catch {
        Write-Error "Failed to process directory: $_"
        return @()
    }
}
#endregion

# Note: Functions are automatically available when dot-sourced
# No Export-ModuleMember needed for .ps1 files