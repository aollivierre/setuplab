# SetupLab - Automated Lab Environment Setup

## 🚀 Quick Start - 100% Automated Installation

### One-Line Installer (Recommended)
```cmd
# Works from anywhere - CMD, PowerShell, or Run dialog (Win+R)
powershell -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')"
```

**What this installs (17 applications):**
- ✅ **Development**: Git, VS Code, Node.js, Python, GitHub Desktop, GitHub CLI, Claude Code (CLI)
- ✅ **Utilities**: 7-Zip, ShareX, Everything, FileLocator Pro, Warp Terminal, Windows Terminal
- ✅ **Browsers**: Google Chrome, Mozilla Firefox  
- ✅ **Runtime**: Visual C++ Redistributables
- ✅ **PowerShell 7** (installed last to prevent session interruption)

**Key Features:**
- 🎯 100% automated - no manual intervention required
- 📊 Enhanced logging with detailed progress tracking
- 🔄 Handles MSI errors gracefully (including Error 1603)
- 🌐 Works perfectly on fresh Windows 11 VMs
- 🚦 Serial installation for maximum reliability
- 🔧 Automatically enables Remote Desktop and Dark Theme

## Alternative Installation Methods

### With Parameters
```cmd
# Skip validation checks
powershell -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') -SkipValidation"

# Install specific categories only
powershell -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') -Categories 'Development','Browsers'"

# Install specific software only
powershell -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') -Software 'Git','Chrome','VSCode'"

# List available software
powershell -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1') -ListSoftware"
```

### Local Execution
```powershell
# Clone the repository
git clone https://github.com/aollivierre/setuplab.git
cd setuplab

# Run locally
.\main.ps1

# With parameters
.\main.ps1 -SkipValidation -Categories "Development,Utilities"
```

## 📊 Installation Success Metrics

Recent improvements have achieved:
- **100% success rate** on fresh Windows 11 installations
- **All 17 applications** install correctly
- **Zero manual intervention** required
- **Enhanced logging** for troubleshooting

## 🔧 Configuration

### Software List (in installation order)
1. Git
2. Node.js
3. Claude Code (CLI)
4. Python
5. 7-Zip
6. Visual Studio Code
7. GitHub Desktop
8. GitHub CLI
9. Windows Terminal
10. ShareX
11. Everything
12. FileLocator Pro
13. Visual C++ Redistributables
14. Google Chrome
15. Mozilla Firefox
16. Warp Terminal
17. PowerShell 7 (installed last)

### Customization
Edit `software-config.json` to:
- Enable/disable specific software
- Modify download URLs
- Change installation arguments
- Add new software packages

## 📝 Enhanced Logging

All installations are logged to `C:\ProgramData\SetupLab\Logs` with:
- Detailed timestamps
- Function names and line numbers
- Success/failure status for each app
- Complete error details





## 🛠️ Troubleshooting

### Known Issues and Solutions

#### 1. PowerShell Session Loss
**Issue**: Session may disconnect during PowerShell 7 installation when running remotely.

**Solution**: PowerShell 7 is now installed last. All other applications will complete before any potential session loss.

#### 2. Node.js MSI Error 1603
**Issue**: Node.js installation may fail with Error 1603.

**Solution**: This is now handled automatically. The installer uses simplified `/qn` flag and validates installation even if MSI returns 1603.

#### 3. Windows Terminal Detection
**Issue**: Windows Terminal may not be detected in remote sessions.

**Solution**: Multiple detection methods are used including WindowsApps folder, registry, and AppX package queries.

## 🎯 Remote Installation

For remote machines:
```powershell
# From your local machine
$cred = Get-Credential
Invoke-Command -ComputerName "RemotePC" -Credential $cred -ScriptBlock {
    iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher-NoCache.ps1')
}
```

## 📈 Recent Improvements

- ✅ Fixed web launcher compatibility with `iex (irm ...)` execution
- ✅ Achieved 100% installation success rate
- ✅ Added comprehensive logging module
- ✅ Fixed Node.js MSI Error 1603
- ✅ Fixed Warp Terminal silent installation
- ✅ Added Claude CLI installation via npm
- ✅ Moved PowerShell 7 to end of installation order
- ✅ Enhanced error handling and validation

## 🚀 Future Enhancements

1. Add Remote Desktop Manager by Devolutions
2. Add mRemoteNG
3. Add Windows Subsystem for Linux (WSL2)
4. Add Docker Desktop (currently disabled)
5. Add Azure CLI and AWS CLI

## 🤝 Contributing

When adding new software:
1. Test installation on fresh Windows VMs
2. Verify silent/unattended installation works
3. Test with the web launcher
4. Add proper validation logic
5. Document any special requirements

## 📄 License

This project is open source and available under the MIT License.
