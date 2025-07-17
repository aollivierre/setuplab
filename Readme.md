# Setup Instructions

### Call using PowerShell:

- **Recommended: Using Web Launcher (downloads all dependencies)**:
    ```powershell
    iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1')
    ```
    
    Or with parameters:
    ```powershell
    & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -SkipValidation -MaxConcurrency 6
    ```

- **Alternative: Direct execution (for simple scripts only)**:
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
  # Install everything with defaults
  iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1')

  # Skip validation and use 6 concurrent installs
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -SkipValidation -MaxConcurrency 6

  # Install only Development and Browsers categories
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -Categories "Development","Browsers"

  # Install specific software only
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -Software "Git","Chrome","VSCode"

  # List all available software
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -ListSoftware
  ```

  🎯 Configuration

  Edit software-config.json to:
  - Enable/disable specific software
  - Modify download URLs
  - Change installation arguments
  - Add new software packages

  The new system maintains all functionality from the original scripts while adding parallel execution, better error handling, and a cleaner architecture!





Future work needed:


1- Add Chrome


2- Add FireFox


3- Add Remote Desktop Manager by Devolutions


4- Add mRemoteNG


5- Make all installers go in parallel instead of series


7- Skip pre-install validations on new installs


8- improve detection of sofware


9- bring in the EnhancedPS Tools Module to re-use code instead of repeating function def in each ps1 script
