# Handover: Critical Bug in SetupLabCore CUSTOM Installer Handling

## 🎯 YOUR MISSION
Fix the CUSTOM installer bug in SetupLabCore.psm1 that prevents Claude CLI from installing. Test ONLY these 3 components:
1. **Git** (prerequisite)
2. **Node.js** (prerequisite) 
3. **Claude CLI** (depends on Git and Node.js)

## 🚨 THE CRITICAL BUG

**Error**: `"Cannot bind argument to parameter 'Path' because it is an empty string."`

**Location**: This error occurs INSIDE SetupLabCore.psm1 when handling CUSTOM type installers, NOT in the install-claude-cli.ps1 script itself.

**Evidence**:
```
PS>TerminatingError(Test-Path): "Cannot bind argument to parameter 'Path' because it is an empty string."
>> TerminatingError(Invoke-SetupInstaller): "Cannot bind argument to parameter 'Path' because it is an empty string."
[2025-07-31 22:33:01] [Error] Failed to install Claude Code (CLI): Cannot bind argument to parameter 'Path' because it is an empty string.
```

**Key Finding**: The install-claude-cli.ps1 script works perfectly when run directly, but fails when invoked through SetupLabCore's CUSTOM installer mechanism.

## 📁 KEY FILES YOU MUST EXAMINE

### 1. **SetupLabCore.psm1** (C:\code\setuplab\SetupLabCore.psm1)
   - **Lines 1080-1127**: CUSTOM installer handling in Start-SerialInstallation
   - **Lines 649-688**: CUSTOM case in Invoke-SetupInstaller function
   - **THE BUG IS HERE**: Look for Test-Path calls with potentially empty variables

### 2. **software-config.json** (C:\code\setuplab\software-config.json)
   - **Line 89**: Git configuration
   - **Line 159**: Node.js configuration  
   - **Line 236**: Claude CLI configuration
   - Note: Claude CLI uses `installType: "CUSTOM"`

### 3. **install-claude-cli.ps1** (C:\code\setuplab\install-claude-cli.ps1)
   - This script WORKS FINE in isolation
   - Has proper error handling and npm directory creation
   - The issue is NOT here

## 🔍 WHAT WE KNOW

1. **Direct execution works**:
   ```powershell
   npm install -g @anthropic-ai/claude-code  # ✅ Works
   & "C:\code\setuplab\install-claude-cli.ps1"  # ✅ Works
   ```

2. **SetupLab execution fails**:
   ```powershell
   iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
   # ❌ Fails at Claude CLI with "empty string" error
   ```

3. **The error happens BEFORE install-claude-cli.ps1 even executes**

## 🎯 FOCUSED TEST APPROACH

### Step 1: Create Minimal Test Configuration
Create a new file `test-config-minimal.json` with ONLY:
```json
{
    "software": [
        {
            "name": "Git",
            "enabled": true,
            "installType": "EXE",
            // ... (copy from main config)
        },
        {
            "name": "Node.js", 
            "enabled": true,
            "installType": "MSI",
            // ... (copy from main config)
        },
        {
            "name": "Claude Code (CLI)",
            "enabled": true,
            "installType": "CUSTOM",
            "customInstallScript": "install-claude-cli.ps1",
            "executablePath": "%APPDATA%\\npm\\claude.cmd",
            // ... (copy from main config)
        }
    ]
}
```

### Step 2: Add Debugging to SetupLabCore.psm1

Focus on these areas:

1. **In Start-SerialInstallation** (around line 1100):
```powershell
# Add debugging BEFORE any path operations
Write-SetupLog "DEBUG: customInstallScript = '$($installation.customInstallScript)'" -Level Debug
Write-SetupLog "DEBUG: PSScriptRoot = '$PSScriptRoot'" -Level Debug
Write-SetupLog "DEBUG: Resolved scriptPath = '$scriptPath'" -Level Debug
```

2. **In Invoke-SetupInstaller** (around line 665):
```powershell
# Add debugging BEFORE the & operator
Write-SetupLog "DEBUG: About to execute: $CustomInstallScript" -Level Debug
Write-SetupLog "DEBUG: Script exists: $(Test-Path $CustomInstallScript)" -Level Debug
```

### Step 3: Test Execution Path
1. Test Git installation (should work - it's EXE type)
2. Test Node.js installation (should work - it's MSI type)
3. Test Claude CLI installation (will fail - debug why)

## 🐛 SUSPECTED BUG LOCATIONS

Based on analysis, check these specific areas:

1. **Variable expansion issues**: The executablePath uses `%APPDATA%`, which might not be expanded correctly
2. **Empty $PSScriptRoot**: In module context, $PSScriptRoot might be empty
3. **Path resolution**: The Join-Path operations might be producing empty results

## 📋 TASK BREAKDOWN

### TASK 1: Reproduce the Issue (15 min)
- [ ] Create minimal test config with only Git, Node.js, Claude CLI
- [ ] Run test and confirm the "empty string" error occurs
- [ ] Note the exact line number where it fails

### TASK 2: Add Comprehensive Debugging (30 min)
- [ ] Add Write-SetupLog statements before EVERY Test-Path call in CUSTOM handling
- [ ] Log ALL variables used in path operations
- [ ] Add try-catch blocks to capture the exact failing line

### TASK 3: Fix the Root Cause (45 min)
- [ ] Identify which variable is empty
- [ ] Implement proper null/empty checks
- [ ] Test the fix with minimal config

### TASK 4: Verify Dependencies Work (15 min)
- [ ] Ensure Git installs first
- [ ] Ensure Node.js installs second
- [ ] Ensure Claude CLI can find both prerequisites

## 🧪 TEST COMMANDS

```powershell
# Test on remote VM (198.18.1.157)
$cred = Get-Credential -UserName "xyz\administrator" # Password: Default1234
Enter-PSSession -ComputerName 198.18.1.157 -Credential $cred

# Direct test (this works)
npm install -g @anthropic-ai/claude-code

# Module test (this fails)
Import-Module C:\code\setuplab\SetupLabCore.psm1 -Force
# Run with minimal config
```

## ⚠️ IMPORTANT NOTES

1. **DO NOT** modify install-claude-cli.ps1 - it works fine
2. **DO NOT** test all 16 applications - focus only on Git, Node.js, Claude CLI
3. **DO NOT** create new workarounds - fix the root cause in SetupLabCore.psm1
4. The issue is a **Test-Path** command receiving an empty string somewhere in the CUSTOM installer handling

## 🎯 SUCCESS CRITERIA

When you're done:
1. Git installs successfully ✅
2. Node.js installs successfully ✅
3. Claude CLI installs successfully ✅
4. The "empty string" error is eliminated
5. You've identified the exact line causing the issue

## 💡 HYPOTHESIS

The most likely cause is that `$PSScriptRoot` is empty in module context, causing Join-Path to produce an empty result, which then gets passed to Test-Path. Check this first!

Good luck! This is a focused debugging task - the issue is isolated to how SetupLabCore.psm1 handles CUSTOM type installers.