<#
.SYNOPSIS
    Quick script to replace Unicode in current directory
.DESCRIPTION
    Simple wrapper for the most common use case - replace Unicode in all PS files in current directory
#>

[CmdletBinding()]
param(
    [switch]$PreviewOnly,
    [switch]$Recurse
)

$toolPath = Join-Path $PSScriptRoot "Replace-UnicodeInScripts.ps1"

Write-Host "Unicode Replacement Tool - Quick Mode" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($PreviewOnly) {
    Write-Host "[PREVIEW MODE] No files will be modified" -ForegroundColor Yellow
}

Write-Host "`nProcessing PowerShell files in: $(Get-Location)" -ForegroundColor White

& $toolPath -Path (Get-Location) -PreviewOnly:$PreviewOnly -Recurse:$Recurse

Write-Host "`nTip: Use -PreviewOnly to see what would be changed" -ForegroundColor Gray
Write-Host "Tip: Use -Recurse to process subdirectories" -ForegroundColor Gray