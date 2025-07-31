# SetupLab Remote Testing Guide

## Current Situation
- **Local VM**: EHJ02-NOTSYNCED on domain **abc.local**
- **Remote VM**: Windows 11 machine at **198.18.1.153** on domain **xyz.local**
- **Issue**: Cross-domain PowerShell remoting is blocked

## Testing Options

### Option 1: Copy Files via Network Share (Recommended)
1. Share the SetupLab folder from this machine:
   ```powershell
   # On this machine (abc.local)
   New-SmbShare -Name "SetupLab" -Path "C:\code\setuplab" -FullAccess "Everyone"
   ```

2. On the remote machine (198.18.1.153), access the share:
   ```powershell
   # Connect with abc domain credentials
   net use \\198.18.1.110\SetupLab /user:abc\administrator Default1234
   
   # Copy files locally
   robocopy \\198.18.1.110\SetupLab C:\Temp\SetupLab /E
   ```

3. Run the test script:
   ```powershell
   cd C:\Temp\SetupLab
   .\Test-RemoteInstallation.ps1 -RunActualInstall
   ```

### Option 2: Use Remote Launcher Script
1. Copy `SetupLab-RemoteLauncher.ps1` to the remote machine via:
   - RDP copy/paste
   - USB drive
   - Email/web download

2. Run on remote machine as administrator:
   ```powershell
   .\SetupLab-RemoteLauncher.ps1 -SourcePath "\\198.18.1.110\c$\code\setuplab"
   ```

### Option 3: Manual Testing via RDP
1. RDP to 198.18.1.153:
   - Username: `xyz\administrator`
   - Password: `Default1234`

2. Copy the following files:
   - `Test-RemoteInstallation.ps1`
   - All SetupLab files

3. Run the test script

## Key Improvements Made

### 1. Enhanced Logging System
- **Location**: `C:\ProgramData\SetupLab\Logs`
- **Features**:
  - Line numbers and function names
  - Timestamps with milliseconds
  - Thread-safe file writing
  - Detailed error stack traces
  - Structured log sections

### 2. Updated Modules
- **SetupLabLogging.psm1**: New enhanced logging module
- **SetupLabCore.psm1**: Updated to use enhanced logging
- **main.ps1**: Serial installation for better reliability

### 3. Test Scripts Created
- **Test-RemoteInstallation.ps1**: Comprehensive system validation
- **SetupLab-RemoteLauncher.ps1**: Cross-domain launcher
- **enable-cross-domain-remoting.ps1**: TrustedHosts configuration

## Known Issues to Test

1. **Silent Installation Failures**
   - Some apps may show UI despite silent flags
   - Check log files for exit codes

2. **Application Detection**
   - Post-install validation may report false negatives
   - Registry paths may vary by installer

3. **NPM Package Installation**
   - Requires Node.js installed first
   - May timeout on slow connections

4. **MSIX/Appx Packages**
   - Windows Terminal requires Windows 10 1903+
   - May conflict with inbox versions

## Testing Checklist

- [ ] System prerequisites check passes
- [ ] All required files copied successfully
- [ ] Logging writes to C:\ProgramData\SetupLab\Logs
- [ ] 7-Zip installs silently
- [ ] Git installs silently
- [ ] Visual Studio Code installs silently
- [ ] Node.js installs and npm works
- [ ] Chrome/Firefox install silently
- [ ] PowerShell 7 installs successfully
- [ ] Windows Terminal installs (MSIX)
- [ ] Warp Terminal installs to user profile
- [ ] Dark theme applies correctly
- [ ] Remote Desktop enables properly

## Log Analysis

After running, check logs at:
```
C:\ProgramData\SetupLab\Logs\SetupLab_[timestamp].log
```

Look for:
- `[ERROR]` entries for failures
- Exit codes from installers
- Stack traces for exceptions
- Installation completion status

## Next Steps

1. Test on the remote Windows 11 machine
2. Review logs for any failures
3. Update silent install arguments as needed
4. Fix any validation issues
5. Ensure all applications install without user interaction