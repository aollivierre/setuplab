<#
.SYNOPSIS
    Add new Unicode character mapping to the configuration
.DESCRIPTION
    Helper script to easily add new Unicode to ASCII mappings
.PARAMETER UnicodeChar
    The Unicode character to map
.PARAMETER Replacement
    The ASCII replacement text
.PARAMETER Category
    Category for the mapping (symbols, emojis, currency, math)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$UnicodeChar,
    
    [Parameter(Mandatory=$true)]
    [string]$Replacement,
    
    [ValidateSet("symbols", "emojis", "currency", "math")]
    [string]$Category = "symbols"
)

$configPath = Join-Path $PSScriptRoot "Config\UnicodeReplacements.json"

try {
    # Load existing config
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    # Check if character already exists
    $exists = $false
    foreach ($cat in $config.replacements.PSObject.Properties) {
        if ($cat.Value.PSObject.Properties.Name -contains $UnicodeChar) {
            Write-Host "[WARNING] Character '$UnicodeChar' already mapped to '$($cat.Value.$UnicodeChar)' in category '$($cat.Name)'" -ForegroundColor Yellow
            $exists = $true
            break
        }
    }
    
    if (-not $exists) {
        # Add new mapping
        $config.replacements.$Category | Add-Member -NotePropertyName $UnicodeChar -NotePropertyValue $Replacement -Force
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        
        Write-Host "[SUCCESS] Added mapping: '$UnicodeChar' -> '$Replacement' in category '$Category'" -ForegroundColor Green
        
        # Show character info
        $charCode = [int][char]$UnicodeChar
        Write-Host "[INFO] Unicode: U+$($charCode.ToString('X4')) (decimal: $charCode)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Error "Failed to update configuration: $_"
}