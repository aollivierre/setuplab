# Critical Handover: Claude CLI Installation Failure in SetupLab

## 🚨 CRITICAL ISSUE SUMMARY

The Claude CLI installation consistently fails with the error:
```
[2025-07-31 21:19:41] [Error] Failed to install Claude CLI: Cannot bind argument to parameter 'Path' because it is an empty string.
```

This error occurs on a fresh Windows 11 VM (198.18.1.157) when running the SetupLab web launcher, despite multiple attempts to fix it.

## 📍 Environment Details

- **Remote Machine**: 198.18.1.157 (Windows 11, Fresh from checkpoint)
- **Domain**: xyz.local
- **User**: xyz\administrator
- **Password**: Default1234
- **Current State**: VM restored from checkpoint, completely fresh
- **SetupLab Version**: v2.0.0 (2025-07-31)

## 🔍 Key Findings from Log Analysis

1. **Web Launcher Working**: Version 2.0.0 downloads all files successfully
2. **Claude CLI Fix Verified**: "[OK] Claude CLI fix verified in downloaded file"
3. **File Size**: install-claude-cli.ps1 - 3,544 bytes (includes our fixes)
4. **Node.js Installed**: Successfully installed v22.17.1 before Claude CLI attempt
5. **Error Timing**: Occurs at step [14/16] during serial installation

## 🐛 Root Cause Analysis

The error "Cannot bind argument to parameter 'Path' because it is an empty string" indicates that:

1. **Something is calling a PowerShell cmdlet with an empty Path parameter**
2. **This is happening WITHIN the SetupLab framework, not the install-claude-cli.ps1 script itself**

### What We've Already Fixed (But Still Failing):

1. ✅ Added null check for $currentPath in install-claude-cli.ps1
2. ✅ Added validation for $npmGlobalDir 
3. ✅ Added directory context management in SetupLabCore.psm1
4. ✅ Removed all Unicode characters from scripts
5. ✅ Implemented cache busting in web launcher

### The Real Problem:

The issue appears to be in how SetupLabCore.psm1 handles CUSTOM type installations. When we test the install-claude-cli.ps1 script directly on the remote machine, it works perfectly. But when invoked through SetupLab, it fails immediately.

## 🎯 CRITICAL TESTING REQUIREMENTS

### YOU MUST TEST ON THE REMOTE MACHINE UNTIL SUCCESS!

1. **Connect to Remote Machine**:
   ```powershell
   $cred = Get-Credential  # Use xyz\administrator / Default1234
   Enter-PSSession -ComputerName 198.18.1.157 -Credential $cred
   ```

2. **Test Web Launcher**:
   ```powershell
   iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
   ```

3. **Check Specific Logs**:
   ```powershell
   # Check main SetupLab logs
   Get-ChildItem "C:\ProgramData\SetupLab\Logs\*.txt" | Sort LastWriteTime -Desc | Select -First 1 | Get-Content

   # Check temp folder logs
   Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort LastWriteTime -Desc | Select -First 1
   ```

## 🔧 Debugging Steps You MUST Follow

### Step 1: Isolate the Exact Error Source

```powershell
# On remote machine, find the exact line causing the error
$tempFolder = Get-ChildItem "$env:TEMP\SetupLab_*" -Directory | Sort LastWriteTime -Desc | Select -First 1
$corePath = Join-Path $tempFolder.FullName "SetupLabCore.psm1"

# Add debugging to the CUSTOM installer section (around line 661)
# Log ALL parameters being passed
```

### Step 2: Test install-claude-cli.ps1 Directly

```powershell
# Download and test the script directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1" -OutFile "$env:TEMP\test-claude.ps1"
& "$env:TEMP\test-claude.ps1"
# This SHOULD work - if it doesn't, we have a different issue
```

### Step 3: Trace the Execution Path

The error likely occurs in one of these places:
1. **SetupLabCore.psm1** - Line ~1081 where it builds $scriptPath
2. **SetupLabCore.psm1** - Line ~1086 where it calls Invoke-SetupInstaller
3. **SetupLabCore.psm1** - Line ~661 where it executes the custom script

## 🚀 Potential Solutions to Try

### Solution 1: Fix Empty Path in Script Resolution

```powershell
# In SetupLabCore.psm1, around line 1078-1081
$scriptPath = if ([System.IO.Path]::IsPathRooted($installation.customInstallScript)) {
    $installation.customInstallScript
} else {
    # This might be the issue - $PSScriptRoot could be empty in some contexts
    $resolvedPath = Join-Path $PSScriptRoot $installation.customInstallScript
    if (-not $resolvedPath -or -not (Test-Path $resolvedPath)) {
        # Fallback to script in same directory as module
        $moduleDir = Split-Path (Get-Module SetupLabCore).Path -Parent
        Join-Path $moduleDir $installation.customInstallScript
    } else {
        $resolvedPath
    }
}
```

### Solution 2: Add Comprehensive Error Logging

```powershell
# Add before line 661 in Invoke-SetupInstaller
Write-SetupLog "CUSTOM Script Debug:" -Level Debug
Write-SetupLog "  Script Path: $CustomInstallScript" -Level Debug
Write-SetupLog "  Script Exists: $(Test-Path $CustomInstallScript)" -Level Debug
Write-SetupLog "  Current Directory: $(Get-Location)" -Level Debug
Write-SetupLog "  PSScriptRoot: $PSScriptRoot" -Level Debug
```

### Solution 3: Wrap the Custom Script Execution

```powershell
# Replace the simple & $CustomInstallScript with:
try {
    $scriptContent = Get-Content $CustomInstallScript -Raw
    $scriptBlock = [scriptblock]::Create($scriptContent)
    & $scriptBlock
} catch {
    Write-SetupLog "Custom script execution failed: $_" -Level Error
    Write-SetupLog "Script path was: $CustomInstallScript" -Level Error
    throw
}
```

## 📋 Verification Checklist

After implementing fixes, verify on the remote machine:

- [ ] Run web launcher from scratch
- [ ] Claude CLI installs without error
- [ ] Verify with: `cmd /c "$env:APPDATA\npm\claude.cmd" --version`
- [ ] Check all 16 applications installed successfully
- [ ] Review SetupLab logs for any warnings

## 🎯 Success Criteria

The fix is ONLY complete when:
1. The web launcher runs successfully on 198.18.1.157
2. Claude CLI installs without any errors
3. All 16 applications show as successfully installed
4. The fix works on a fresh VM restore (not just after manual fixes)

## ⚠️ Critical Notes

1. **DO NOT** assume the fix works without testing on 198.18.1.157
2. **DO NOT** only test locally - the issue only manifests on fresh VMs
3. **DO NOT** skip the full web launcher test - test the complete flow
4. **ALWAYS** check the actual SetupLab logs, not just console output

## 🔗 Related Files to Review

1. `C:\code\setuplab\SetupLabCore.psm1` - Lines 1070-1090 (CUSTOM handler)
2. `C:\code\setuplab\SetupLabCore.psm1` - Lines 649-674 (Invoke-SetupInstaller)
3. `C:\code\setuplab\install-claude-cli.ps1` - Already has fixes but still failing
4. `C:\code\setuplab\software-config.json` - Line 248 (Claude CLI config)

## 🆘 If All Else Fails

Consider changing Claude CLI from CUSTOM type to NPM type in software-config.json:
```json
{
    "name": "Claude CLI",
    "enabled": true,
    "installType": "NPM",
    "npmPackage": "@anthropic-ai/claude-code",
    "category": "Development"
}
```

But this should be a last resort - we need to understand why CUSTOM installers are failing.

---

**Remember**: The issue is NOT in the install-claude-cli.ps1 script itself - it works fine when run directly. The issue is in how SetupLabCore.psm1 invokes CUSTOM type installers. Focus your debugging there!