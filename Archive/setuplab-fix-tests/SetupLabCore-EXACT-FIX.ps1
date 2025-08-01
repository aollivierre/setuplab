# EXACT FIX for SetupLabCore.psm1 Lines 1109-1117

# CURRENT BUGGY CODE (Lines 1109-1117):
if (-not $PSScriptRoot) {
    # Fallback: use module directory
    $moduleDir = Split-Path (Get-Module SetupLabCore).Path -Parent
    Write-SetupLog "  PSScriptRoot is empty, using module directory: $moduleDir" -Level Debug
    Join-Path $moduleDir $installation.customInstallScript
} else {
    Join-Path $PSScriptRoot $installation.customInstallScript
}

# FIXED CODE:
if (-not $PSScriptRoot) {
    # Fallback: use module directory
    $module = Get-Module SetupLabCore
    if ($module) {
        $moduleDir = Split-Path $module.Path -Parent
        Write-SetupLog "  PSScriptRoot is empty, using module directory: $moduleDir" -Level Debug
        Join-Path $moduleDir $installation.customInstallScript
    } else {
        # If module is not loaded, try to find it
        $modulePath = Get-Module -ListAvailable SetupLabCore | Select-Object -First 1
        if ($modulePath) {
            $moduleDir = Split-Path $modulePath.Path -Parent
            Write-SetupLog "  PSScriptRoot is empty, found module at: $moduleDir" -Level Debug
            Join-Path $moduleDir $installation.customInstallScript
        } else {
            # Last resort: use temp directory where files were downloaded
            $tempDir = Split-Path $MyInvocation.MyCommand.Path -Parent
            Write-SetupLog "  PSScriptRoot and module not found, using: $tempDir" -Level Debug
            Join-Path $tempDir $installation.customInstallScript
        }
    }
} else {
    Join-Path $PSScriptRoot $installation.customInstallScript
}