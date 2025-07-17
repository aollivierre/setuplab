# AI Agent Handover: Fix Warp Terminal Infinite Loop Issue

## Critical Issue Summary
The SetupLab installation script is experiencing an infinite loop when checking if Warp Terminal is installed. The script repeatedly outputs "Warp Terminal found in registry" and "Warp Terminal is already installed - skipping" hundreds of times, preventing the installation process from completing.

## Context and Background
- **Script Location**: `C:\Code\setuplab\`
- **Execution Method**: Web launcher downloading from GitHub
- **Affected Component**: Warp Terminal installation check
- **Secondary Issue**: "Stream was not readable" error in logging function

## Root Cause Analysis Areas

### 1. Parallel Job Management Issue
The infinite loop suggests a problem in the parallel job management system. Look for:
- Race conditions in parallel job execution
- Missing job completion signals
- Incorrect job state management

### 2. Registry Check Logic
The software detection repeatedly finds Warp Terminal in the registry, indicating:
- Possible regex pattern matching issue
- Multiple registry entries being matched
- Loop termination condition missing

## Files to Examine (Priority Order)

### 1. **SetupLabCore.psm1** (Primary Focus)
**Location**: `C:\Code\setuplab\SetupLabCore.psm1`

**Key Functions to Check**:
- `Test-SoftwareInstalled` - Look for:
  ```powershell
  # Search for the function that checks registry
  # Pattern: function Test-SoftwareInstalled
  # Look for registry path loops
  # Check if it's returning multiple matches for Warp
  ```

- `Start-ParallelInstallation` - Look for:
  ```powershell
  # Search for job management logic
  # Pattern: Start-Job, Receive-Job, Wait-Job
  # Check job cleanup and completion logic
  ```

- `Write-SetupLog` - Fix the streaming error at line 47:
  ```powershell
  # Line 47: Add-Content -Path $logFilePath -Value $logMessage -Force
  # The log file handle might be locked by parallel processes
  ```

### 2. **software-config.json**
**Location**: `C:\Code\setuplab\software-config.json`

**Check Warp Terminal Entry** (around line 199-209):
```json
{
  "name": "Warp Terminal",
  "registryName": "Warp",
  // Check if this pattern is too broad
}
```

### 3. **main.ps1**
**Location**: `C:\Code\setuplab\main.ps1`

**Look for**:
- How it calls `Start-ParallelInstallation`
- Any loops around software checking

## Specific Search Patterns

### 1. Find All Warp-Related Code
```powershell
# Use these grep patterns:
grep -i "warp" *.ps1 *.psm1
grep -i "Test-SoftwareInstalled.*warp" *.ps1 *.psm1
grep -i "registryName.*warp" *.json
```

### 2. Find Parallel Job Logic
```powershell
# Search for job management:
grep -E "(Start-Job|Receive-Job|Wait-Job|ForEach.*-Parallel)" *.ps1 *.psm1
grep -E "while.*job" *.ps1 *.psm1
```

### 3. Find Registry Check Logic
```powershell
# Search for registry patterns:
grep -E "Get-ItemProperty.*Uninstall" *.ps1 *.psm1
grep -E "Where-Object.*DisplayName" *.ps1 *.psm1
```

## Validation Steps (Without Running Installer)

### 1. Test Registry Detection in Isolation
Create `Test-WarpRegistryDetection.ps1`:
```powershell
# Test what Test-SoftwareInstalled finds for Warp
# Check all registry paths
# Count how many Warp entries exist
# Verify the -like pattern matching
```

### 2. Simulate Parallel Job Behavior
Create `Test-ParallelJobLogic.ps1`:
```powershell
# Test job creation and cleanup
# Verify job state transitions
# Check for job result accumulation
```

### 3. Check for Circular Dependencies
- Look for recursive function calls
- Check if job creates more jobs
- Verify loop exit conditions

## Likely Fix Areas

### 1. **Registry Check Pattern** (Most Likely)
The pattern `"Warp"` might be matching multiple entries:
- Warp Terminal
- WarpSetup
- Other Warp-related entries

**Fix**: Make the registry pattern more specific:
```json
"registryName": "Warp Terminal"  // Instead of just "Warp"
```

### 2. **Job Loop Control**
Look for missing break conditions in:
```powershell
# In Start-ParallelInstallation
while ($runningJobs.Count -gt 0) {
    # Need proper exit condition
    # Check if job results are being processed correctly
}
```

### 3. **Logging Concurrency**
Fix the stream error by implementing thread-safe logging:
```powershell
# Use mutex or lock for log file access
# Or use -Append instead of Add-Content
# Consider using Start-Transcript for parallel jobs
```

## Testing Without Installation

### 1. Create Mock Test Script
```powershell
# Test-SetupLabLogic.ps1
# Mock the installation check without actual installation
# Verify the logic flow
# Count execution iterations
```

### 2. Dry Run Mode
Add a `-WhatIf` parameter to test logic without execution:
```powershell
# Add to software check logic
if ($WhatIf) {
    Write-Host "[DRYRUN] Would check: $($software.name)"
    continue
}
```

## CRITICAL FINDING FROM DIAGNOSTIC
The diagnostic revealed that:
1. The registry entry has DisplayName = "Warp" (not "Warp Terminal")
2. The software-config.json has registryName = "Warp" 
3. The Test-SoftwareInstalled function is missing a "found flag" to exit early
4. This causes the check to run repeatedly in parallel jobs

**IMMEDIATE FIX**: Since the registry shows "Warp" as the DisplayName, keep the registryName as "Warp" but fix the Test-SoftwareInstalled function to properly exit after finding a match.

## Expected Outcomes
1. Warp Terminal should be checked exactly once
2. No infinite loops in job processing
3. Clean log file writes without stream errors
4. Clear indication of what's installed vs. what needs installation

## Priority Actions
1. **FIRST**: Fix Test-SoftwareInstalled function to exit after finding a match (add $found flag)
2. **SECOND**: Add job deduplication to prevent multiple checks of same software
3. **THIRD**: Fix concurrent logging issues (stream not readable error)
4. **FOURTH**: Add timeout mechanism to parallel jobs to prevent infinite loops

## Additional Notes
- The issue manifests when running from the web launcher
- Other software (Git, VS Code, etc.) work correctly
- This suggests a Warp-specific pattern matching issue
- The parallel nature makes debugging harder

## Commands for Quick Diagnosis
```powershell
# Check current Warp registry entries
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Warp*" } | Select DisplayName, PSChildName

# Check HKCU as well
Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Warp*" } | Select DisplayName, PSChildName
```

Remember: Do NOT run the actual installer. Focus on logic validation and pattern testing only.