# EXACT FIX for SetupLabCore.psm1 Line 650
# Change this:
if (-not $CustomInstallScript) {
    throw "Custom install script path is required for CUSTOM install type"
}

# To this:
if (-not $CustomInstallScript -or $CustomInstallScript.Trim() -eq '') {
    throw "Custom install script path is required for CUSTOM install type"
}

# This will catch both $null AND empty string values before they reach Test-Path