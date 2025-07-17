# SetupLab - Automated Lab Environment Setup

## Quick Start

### Recommended: Cache-Busting Web Launcher
This command ensures you always get the latest version by bypassing GitHub's CDN cache:

```powershell
# One-line installer (works on fresh Windows installations):
powershell -command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')"
```

### Alternative Commands

- **Standard Web Launcher** (may use cached versions):
    ```powershell
    # For fresh machines (sets execution policy for current session):
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1')
    ```
    
    Or with parameters:
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -SkipValidation -MaxConcurrency 6
    ```

- **Direct execution** (not recommended - for simple scripts only):
    ```powershell
    powershell -Command "iex (irm https://raw.githubusercontent.com/aollivierre/setuplab/main/main.ps1)"
    ```
    Note: This method won't work properly as main.ps1 requires additional files (SetupLabCore.psm1 and software-config.json)

Perfect! I've successfully created a modern, modular PowerShell setup framework with the following improvements:

  🚀 Key Features Implemented:

  1. Modular Architecture

  - SetupLabCore.psm1: Centralized module with all shared functions
  - software-config.json: Configuration-driven approach for easy management
  - main.ps1: Clean orchestrator script

  2. Parallel Installation ✅

  - Uses PowerShell jobs for concurrent installations
  - Configurable max concurrency (default: 4)
  - Real-time progress monitoring

  3. New Software Added ✅

  - Google Chrome
  - Mozilla Firefox
  - Warp Terminal

  4. Enhanced Features

  - Skip validation option: -SkipValidation parameter
  - Improved detection: Unified validation across all software
  - Category filtering: Install only specific categories
  - Individual software selection: Install specific packages

  5. Better Organization

  - All old scripts archived in Archive/ folder
  - Centralized logging in Logs/ folder
  - Clean root directory structure

  📦 Usage Examples:

  ## Local Execution:
  ```powershell
  # Install everything with defaults
  .\main.ps1

  # Skip validation and use 6 concurrent installs
  .\main.ps1 -SkipValidation -MaxConcurrency 6

  # Install only Development and Browsers categories
  .\main.ps1 -Categories "Development,Browsers"

  # Install specific software only
  .\main.ps1 -Software "Git,Chrome,VSCode"

  # List all available software
  .\main.ps1 -ListSoftware
  ```

  ## Web Execution (no local files required):
  ```powershell
  # Install everything with defaults (includes execution policy bypass for fresh machines)
  Set-ExecutionPolicy Bypass -Scope Process -Force; iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1')

  # Skip validation and use 6 concurrent installs
  Set-ExecutionPolicy Bypass -Scope Process -Force; & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -SkipValidation -MaxConcurrency 6

  # Install only Development and Browsers categories
  Set-ExecutionPolicy Bypass -Scope Process -Force; & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -Categories "Development","Browsers"

  # Install specific software only
  Set-ExecutionPolicy Bypass -Scope Process -Force; & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -Software "Git","Chrome","VSCode"

  # List all available software
  Set-ExecutionPolicy Bypass -Scope Process -Force; & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -ListSoftware
  ```

  🎯 Configuration

  Edit software-config.json to:
  - Enable/disable specific software
  - Modify download URLs
  - Change installation arguments
  - Add new software packages

  The new system maintains all functionality from the original scripts while adding parallel execution, better error handling, and a cleaner architecture!





## Troubleshooting

### Known Issues and Solutions

#### 1. NPM Package Installation Hanging
**Issue**: Claude Code and other NPM packages may hang indefinitely when installed in PowerShell parallel jobs.

**Solution**: NPM packages have been disabled by default. If you need NPM packages:
- Install them separately after the main installation
- Or run them directly: `npm install -g @anthropic-ai/claude-code`

**Root Cause**: NPM installations can hang when executed inside PowerShell jobs due to process isolation and I/O handling issues.

#### 2. GitHub CDN Caching Issues
**Issue**: Changes to scripts may not be reflected immediately due to GitHub's CDN caching.

**Solution**: Always use the cache-busting launcher:
```powershell
powershell -command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')"
```

#### 3. Warp Terminal Detection
**Issue**: Previous versions had an infinite loop when detecting Warp Terminal.

**Solution**: This has been fixed in the latest version. The detection now works correctly without loops.

## Lessons Learned

### Key Findings from Development

1. **PowerShell Job Limitations**
   - NPM and other interactive tools may hang in PowerShell jobs
   - Jobs have limited I/O handling capabilities
   - Timeout mechanisms may not work reliably for all process types

2. **GitHub CDN Behavior**
   - Raw GitHub URLs are cached aggressively (up to 5 minutes)
   - Cache-busting parameters are essential for development/testing
   - Always test with the cache-busting launcher

3. **Software Detection Best Practices**
   - Check multiple locations (registry, file paths, MSIX packages)
   - Handle user-specific paths with environment variables
   - Version detection requires special handling for different tools

4. **Parallel Installation Considerations**
   - Not all installers work well in parallel
   - Some tools require sequential installation
   - Timeout mechanisms are crucial but may need per-tool tuning

## Future Enhancements

1. ✅ Chrome (Added)
2. ✅ Firefox (Added) 
3. Add Remote Desktop Manager by Devolutions
4. Add mRemoteNG
5. ✅ Parallel installation (Implemented)
6. ✅ Skip pre-install validations (Added -SkipValidation parameter)
7. ✅ Improved software detection (Unified validation system)
8. Integrate EnhancedPS Tools Module for code reuse

## Contributing

When adding new software:
1. Test installation in both sequential and parallel modes
2. Verify timeout mechanisms work correctly
3. Test with the cache-busting launcher
4. Document any special requirements or limitations
