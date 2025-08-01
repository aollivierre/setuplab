#Requires -Version 5.1
<#
.SYNOPSIS
    Core module for SetupLab containing shared functions and utilities
.DESCRIPTION
    This module provides common functionality for all installer scripts including:
    - Admin elevation
    - Logging
    - Download management
    - Software validation
    - Parallel execution support
#>

#region Module Variables
$script:LogPath = Join-Path $PSScriptRoot "Logs"
$script:TempPath = Join-Path $env:TEMP "SetupLab"
$script:ConfigPath = Join-Path $PSScriptRoot "software-config.json"

if (-not (Test-Path $script:LogPath)) {
    New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
}
if (-not (Test-Path $script:TempPath)) {
    New-Item -ItemType Directory -Path $script:TempPath -Force | Out-Null
}
#endregion

# Import enhanced logging module
$loggingModulePath = Join-Path $PSScriptRoot "SetupLabLogging.psm1"
if (Test-Path $loggingModulePath) {
    Import-Module $loggingModulePath -Force
    Initialize-SetupLog -LogName "SetupLab"
}

#region Logging Functions
function Write-SetupLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = "SetupLab_$((Get-Date).ToString('yyyyMMdd')).log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get caller information from call stack
    $callerInfo = ""
    $callStack = Get-PSCallStack
    if ($callStack.Count -gt 1) {
        # Skip the first frame (this function) to get the actual caller
        $caller = $callStack[1]
        $lineNumber = $caller.ScriptLineNumber
        $functionName = $caller.FunctionName
        $scriptName = if ($caller.ScriptName) { Split-Path $caller.ScriptName -Leaf } else { "<Unknown>" }
        
        # Include line info for Debug and Error levels, or when dealing with CUSTOM installer
        if ($Level -in 'Debug', 'Error' -or $Message -match 'CUSTOM|CustomInstallScript|empty string') {
            $callerInfo = " [${scriptName}:${lineNumber}:${functionName}]"
        }
    }
    
    $logMessage = if ($Message) { "[$timestamp] [$Level]${callerInfo} $Message" } else { "" }
    $logFilePath = Join-Path $script:LogPath $LogFile
    
    # Write to log file with retry logic for concurrent access
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            Add-Content -Path $logFilePath -Value $logMessage -Force
            break
        }
        catch {
            $retryCount++
            if ($retryCount -eq $maxRetries) {
                # If all retries fail, try alternative logging method
                try {
                    Out-File -FilePath $logFilePath -InputObject $logMessage -Append -Force
                }
                catch {
                    # Final fallback - just output to console
                    Write-Host "[LOG ERROR] $logMessage" -ForegroundColor Red
                }
            }
            else {
                Start-Sleep -Milliseconds (100 * $retryCount)
            }
        }
    }
    
    # Write to console with color
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Debug'   { 'Gray' }
        default   { 'White' }
    }
    
    if ($Message) {
        Write-Host $logMessage -ForegroundColor $color
        
        # For errors, also log the full stack trace
        if ($Level -eq 'Error' -and $callStack.Count -gt 2) {
            $stackTrace = "Stack trace:"
            for ($i = 2; $i -lt $callStack.Count; $i++) {
                $frame = $callStack[$i]
                $stackTrace += "`n  at $($frame.FunctionName) [$($frame.ScriptName):$($frame.ScriptLineNumber)]"
            }
            Add-Content -Path $logFilePath -Value $stackTrace -Force -ErrorAction SilentlyContinue
            Write-Host $stackTrace -ForegroundColor $color
        }
    } else {
        Write-Host ""
    }
}
#endregion

#region Admin Functions
function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Tests if the current session has administrator privileges
    .DESCRIPTION
        Checks if the current PowerShell session is running with elevated permissions
    .OUTPUTS
        Boolean indicating admin status
    #>
    [CmdletBinding()]
    param()
    
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    <#
    .SYNOPSIS
        Requests administrator elevation for the current script
    .DESCRIPTION
        Re-launches the current script with administrator privileges if not already elevated
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptPath = $PSCommandPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )
    
    if (-not (Test-AdminPrivileges)) {
        Write-SetupLog "Requesting administrator elevation..." -Level Warning
        
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
        
        foreach ($key in $Parameters.Keys) {
            $argList += "-$key"
            if ($Parameters[$key] -ne $true) {
                $argList += "`"$($Parameters[$key])`""
            }
        }
        
        Start-Process PowerShell.exe -Verb RunAs -ArgumentList $argList
        exit
    }
}
#endregion

#region Download Functions
function Start-SetupDownload {
    <#
    .SYNOPSIS
        Downloads a file with retry logic using BITS or WebClient
    .DESCRIPTION
        Attempts to download a file using BITS with fallback to WebClient
    .PARAMETER Url
        The URL of the file to download
    .PARAMETER Destination
        The local path where the file should be saved
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 3)
    .PARAMETER RetryDelay
        Delay in seconds between retries (default: 5)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 5
    )
    
    $attempt = 0
    $success = $false
    
    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++
        
        try {
            Write-SetupLog "Download attempt $attempt of $MaxRetries for: $Url" -Level Info
            
            # Try BITS first
            if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
                $success = $true
                Write-SetupLog "Download completed using BITS" -Level Success
            }
            else {
                throw "BITS not available, falling back to WebClient"
            }
        }
        catch {
            Write-SetupLog "BITS download failed: $_" -Level Warning
            
            try {
                # Fallback to WebClient
                $webClient = New-Object System.Net.WebClient
                try {
                    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                    $webClient.DownloadFile($Url, $Destination)
                    $success = $true
                    Write-SetupLog "Download completed using WebClient" -Level Success
                }
                finally {
                    $webClient.Dispose()
                }
            }
            catch {
                Write-SetupLog "WebClient download failed: $_" -Level Error
                
                if ($attempt -lt $MaxRetries) {
                    Write-SetupLog "Retrying in $RetryDelay seconds..." -Level Warning
                    Start-Sleep -Seconds $RetryDelay
                }
            }
        }
    }
    
    if (-not $success) {
        throw "Failed to download file after $MaxRetries attempts"
    }
    
    return $Destination
}
#endregion

#region Validation Functions
function Test-SoftwareInstalled {
    <#
    .SYNOPSIS
        Checks if software is installed on the system
    .DESCRIPTION
        Searches registry and common installation paths for software
    .PARAMETER Name
        The name of the software to check
    .PARAMETER RegistryName
        Optional specific registry name to search for
    .PARAMETER ExecutablePath
        Optional specific executable path to check
    .PARAMETER MinimumVersion
        Optional minimum version requirement
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$RegistryName,
        
        [Parameter(Mandatory = $false)]
        [string]$ExecutablePath,
        
        [Parameter(Mandatory = $false)]
        [version]$MinimumVersion
    )
    
    # Special handling for Windows Terminal (MSIX package)
    if ($Name -eq "Windows Terminal") {
        # Check OS version - Windows 11 and Server 2025 have Windows Terminal built-in
        $osVersion = [System.Environment]::OSVersion.Version
        $osProductType = (Get-WmiObject -Class Win32_OperatingSystem).ProductType
        
        # Windows 11 is version 10.0.22000+ and ProductType 1 (Workstation)
        # Windows Server 2025 is version 10.0.26100+ and ProductType 2 or 3 (Server)
        $isWindows11 = ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000 -and $osProductType -eq 1)
        $isServer2025 = ($osVersion.Major -eq 10 -and $osVersion.Build -ge 26100 -and $osProductType -ne 1)
        
        if ($isWindows11 -or $isServer2025) {
            $osName = if ($isWindows11) { "Windows 11" } else { "Windows Server 2025" }
            Write-SetupLog "$Name is built-in on $osName (Build $($osVersion.Build)) - skipping installation" -Level Success
            return $true
        }
        
        try {
            $package = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
            if ($package) {
                Write-SetupLog "$Name version $($package.Version) found via MSIX package" -Level Success
                return $true
            }
        } catch {
            Write-SetupLog "Could not check MSIX packages for Windows Terminal" -Level Debug
        }
    }
    
    # Check executable path first if provided
    if ($ExecutablePath) {
        # Expand environment variables in the path
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($ExecutablePath)
        if (Test-Path $expandedPath) {
            $ExecutablePath = $expandedPath
        } else {
            $ExecutablePath = $null
        }
    }
    
    if ($ExecutablePath -and (Test-Path $ExecutablePath)) {
        if ($MinimumVersion) {
            try {
                # Special handling for PowerShell 7
                if ($Name -eq "PowerShell 7") {
                    # Try to get version directly from pwsh.exe
                    $versionOutput = & $ExecutablePath --version 2>$null
                    if ($versionOutput -and $versionOutput -match "PowerShell (\d+\.\d+\.\d+)") {
                        $currentVersion = [version]$matches[1]
                        
                        if ($currentVersion -ge $MinimumVersion) {
                            Write-SetupLog "$Name version $currentVersion found (meets minimum $MinimumVersion)" -Level Success
                            return $true
                        }
                        else {
                            Write-SetupLog "$Name version $currentVersion found but below minimum $MinimumVersion" -Level Warning
                            return $false
                        }
                    }
                }
                
                # Special handling for Git
                if ($Name -eq "Git") {
                    # Try to get version directly from git.exe
                    $versionOutput = & $ExecutablePath --version 2>$null
                    if ($versionOutput -and $versionOutput -match "git version (\d+\.\d+\.\d+)") {
                        $currentVersion = [version]$matches[1]
                        
                        if ($currentVersion -ge $MinimumVersion) {
                            Write-SetupLog "$Name version $currentVersion found (meets minimum $MinimumVersion)" -Level Success
                            return $true
                        }
                        else {
                            Write-SetupLog "$Name version $currentVersion found but below minimum $MinimumVersion" -Level Warning
                            return $false
                        }
                    }
                }
                
                # Standard version detection for other software
                $versionInfo = (Get-Item $ExecutablePath).VersionInfo
                $currentVersion = [version]($versionInfo.ProductVersion -replace '[^\d\.]', '')
                
                if ($currentVersion -ge $MinimumVersion) {
                    Write-SetupLog "$Name version $currentVersion found (meets minimum $MinimumVersion)" -Level Success
                    return $true
                }
                else {
                    Write-SetupLog "$Name version $currentVersion found but below minimum $MinimumVersion" -Level Warning
                    return $false
                }
            }
            catch {
                Write-SetupLog "Could not determine version for $Name from executable, checking registry..." -Level Debug
            }
        }
        else {
            Write-SetupLog "$Name found at: $ExecutablePath" -Level Success
            return $true
        }
    }
    
    # Check registry
    $searchName = if ($RegistryName) { $RegistryName } else { $Name }
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $found = $false
    $meetsVersionRequirement = $false
    
    foreach ($path in $registryPaths) {
        if ($found) { break }  # Exit early if already found
        
        $installed = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$searchName*" } |
            Select-Object -First 1  # Only check first match to avoid duplicates
        
        if ($installed) {
            $found = $true
            
            if ($MinimumVersion -and $installed.DisplayVersion) {
                try {
                    $currentVersion = [version]($installed.DisplayVersion -replace '[^\d\.]', '')
                    
                    if ($currentVersion -ge $MinimumVersion) {
                        Write-SetupLog "$Name version $currentVersion found in registry (meets minimum $MinimumVersion)" -Level Success
                        $meetsVersionRequirement = $true
                    }
                    else {
                        Write-SetupLog "$Name version $currentVersion found but below minimum $MinimumVersion" -Level Warning
                        $meetsVersionRequirement = $false
                    }
                }
                catch {
                    Write-SetupLog "Could not parse version for $Name" -Level Warning
                    # If we can't parse version but need minimum version, consider it not meeting requirement
                    $meetsVersionRequirement = $false
                }
            }
            else {
                # No version requirement or no version info available
                if (-not $MinimumVersion) {
                    Write-SetupLog "$Name found in registry" -Level Success
                    $meetsVersionRequirement = $true
                }
                else {
                    Write-SetupLog "$Name found but version information not available" -Level Warning
                    $meetsVersionRequirement = $false
                }
            }
            
            break  # Exit the loop after processing first match
        }
    }
    
    if ($found) {
        return $meetsVersionRequirement
    }
    
    Write-SetupLog "$Name not found on system" -Level Info
    return $false
}

function Get-InstalledSoftwareVersion {
    <#
    .SYNOPSIS
        Gets the installed version of a software
    .DESCRIPTION
        Retrieves version information from registry or executable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$RegistryName,
        
        [Parameter(Mandatory = $false)]
        [string]$ExecutablePath
    )
    
    # Check executable first
    if ($ExecutablePath -and (Test-Path $ExecutablePath)) {
        try {
            $versionInfo = (Get-Item $ExecutablePath).VersionInfo
            return [version]($versionInfo.ProductVersion -replace '[^\d\.]', '')
        }
        catch {
            Write-SetupLog "Could not get version from executable" -Level Debug
        }
    }
    
    # Check registry
    $searchName = if ($RegistryName) { $RegistryName } else { $Name }
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        $installed = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$searchName*" } |
            Select-Object -First 1
        
        if ($installed -and $installed.DisplayVersion) {
            try {
                return [version]($installed.DisplayVersion -replace '[^\d\.]', '')
            }
            catch {
                Write-SetupLog "Could not parse version from registry" -Level Debug
            }
        }
    }
    
    return $null
}
#endregion

#region Installation Functions
function Invoke-SetupInstaller {
    <#
    .SYNOPSIS
        Executes an installer with appropriate parameters
    .DESCRIPTION
        Runs an installer executable with silent/quiet parameters
    .PARAMETER InstallerPath
        Path to the installer executable
    .PARAMETER Arguments
        Arguments to pass to the installer
    .PARAMETER InstallType
        Type of installer (MSI, EXE, MSIX, NPM)
    .PARAMETER NpmPackage
        NPM package name (for NPM install type)
    .PARAMETER NpmInstallArgs
        Additional arguments for npm install
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('MSI', 'EXE', 'MSIX', 'NPM', 'CUSTOM', 'Auto')]
        [string]$InstallType = 'Auto',
        
        [Parameter(Mandatory = $false)]
        [string]$NpmPackage,
        
        [Parameter(Mandatory = $false)]
        [string[]]$NpmInstallArgs = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$CustomInstallScript
    )
    
    # Log all parameters at entry
    Write-SetupLog "Invoke-SetupInstaller called with:" -Level Debug
    Write-SetupLog "  InstallerPath: '$InstallerPath'" -Level Debug
    Write-SetupLog "  InstallType: '$InstallType'" -Level Debug
    Write-SetupLog "  CustomInstallScript: '$CustomInstallScript'" -Level Debug
    Write-SetupLog "  NpmPackage: '$NpmPackage'" -Level Debug
    
    if ($InstallType -eq 'NPM') {
        # Handle NPM package installation
        if (-not $NpmPackage) {
            throw "NPM package name is required for NPM install type"
        }
        
        Write-SetupLog "Installing NPM package: $NpmPackage" -Level Info
        
        # Check if npm is available
        $npmPath = Get-Command npm -ErrorAction SilentlyContinue
        if (-not $npmPath) {
            throw "npm is not available. Please install Node.js first."
        }
        
        # Verify npm is executable
        try {
            $npmVersion = & npm --version 2>&1
            Write-SetupLog "Using npm version: $npmVersion" -Level Debug
        } catch {
            throw "npm is not working properly: $_"
        }
        
        # Build npm install command
        $npmArgs = @("install", "-g", $NpmPackage) + $NpmInstallArgs
        
        Write-SetupLog "Running: npm $($npmArgs -join ' ')" -Level Debug
        
        # Use cmd.exe to run npm to avoid path and binary compatibility issues
        $npmCommand = "npm $($npmArgs -join ' ')"
        Write-SetupLog "Running: $npmCommand" -Level Debug
        
        # Add timeout and better error handling for npm process
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = "cmd.exe"
        $processStartInfo.Arguments = "/c $npmCommand"
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null
        
        # Wait for process with timeout (60 seconds)
        $timeoutMilliseconds = 60000
        if (-not $process.WaitForExit($timeoutMilliseconds)) {
            Write-SetupLog "NPM installation timed out after 60 seconds" -Level Warning
            $process.Kill()
            throw "NPM installation timed out"
        }
        
        # Get output for debugging
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        if ($stdout) {
            Write-SetupLog "NPM stdout: $stdout" -Level Debug
        }
        if ($stderr) {
            Write-SetupLog "NPM stderr: $stderr" -Level Debug
        }
        
        if ($process.ExitCode -ne 0) {
            throw "NPM installation failed with exit code: $($process.ExitCode)"
        }
        
        Write-SetupLog "NPM package installed successfully" -Level Success
        return
    }
    
    # Skip installer path check for NPM and CUSTOM types
    if ($InstallType -notin @('NPM', 'CUSTOM')) {
        if (-not $InstallerPath) {
            throw "InstallerPath is required for install type: $InstallType"
        }
        if (-not (Test-Path $InstallerPath)) {
            throw "Installer not found: $InstallerPath"
        }
    }
    
    # Determine install type if Auto
    if ($InstallType -eq 'Auto') {
        $extension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        $InstallType = switch ($extension) {
            '.msi'  { 'MSI' }
            '.msix' { 'MSIX' }
            '.msixbundle' { 'MSIX' }
            '.zip' { 'MSI_ZIP' }  # Assume ZIP files contain MSI
            default { 'EXE' }
        }
    }
    
    Write-SetupLog "Installing using $InstallType method" -Level Info
    
    switch ($InstallType) {
        'MSI' {
            $msiArgs = @("/i", "`"$InstallerPath`"") + $Arguments
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
            
            # Handle common MSI error codes
            if ($process.ExitCode -eq 1603) {
                Write-SetupLog "MSI Error 1603 detected - attempting cleanup and retry" -Level Warning
                
                # Wait a moment for any background processes
                Start-Sleep -Seconds 5
                
                # Try again with force restart flag
                $retryArgs = $msiArgs + @("REBOOT=ReallySuppress")
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $retryArgs -Wait -PassThru
            }
        }
        
        'MSIX' {
            try {
                Add-AppxPackage -Path $InstallerPath -ErrorAction Stop
                return
            } catch {
                # Check if it's a version conflict
                if ($_.Exception.Message -match "higher version.*already installed") {
                    Write-SetupLog "A higher version is already installed - skipping" -Level Info
                    return
                } else {
                    throw $_
                }
            }
        }
        
        'EXE' {
            # Start the installer process
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -PassThru
            
            # Wait for the process with a timeout (5 minutes)
            $timeoutSeconds = 300
            $waited = $process.WaitForExit($timeoutSeconds * 1000)
            
            if (-not $waited) {
                Write-SetupLog "Installation process timed out after $timeoutSeconds seconds" -Level Warning
                # Don't kill the process as it might still be installing
            }
        }
        
        'CUSTOM' {
            Write-SetupLog "CUSTOM installer block started" -Level Debug
            Write-SetupLog "CustomInstallScript parameter value: '$CustomInstallScript'" -Level Debug
            Write-SetupLog "Is null: $($null -eq $CustomInstallScript)" -Level Debug
            Write-SetupLog "Is empty: $([string]::IsNullOrWhiteSpace($CustomInstallScript))" -Level Debug
            
            # Enhanced parameter validation
            if (-not $CustomInstallScript -or [string]::IsNullOrWhiteSpace($CustomInstallScript)) {
                Write-SetupLog "ERROR: CustomInstallScript is null or empty!" -Level Error
                Write-SetupLog "Function parameters:" -Level Error
                Write-SetupLog "  InstallerPath: '$InstallerPath'" -Level Error
                Write-SetupLog "  InstallType: '$InstallType'" -Level Error
                Write-SetupLog "  CustomInstallScript: '$CustomInstallScript'" -Level Error
                Write-SetupLog "  Arguments: '$($Arguments -join ' ')'" -Level Error
                
                throw "Custom install script path is required for CUSTOM install type"
            }
            
            Write-SetupLog "About to call Test-Path with: '$CustomInstallScript'" -Level Debug
            try {
                $pathExists = Test-Path $CustomInstallScript -ErrorAction Stop
                Write-SetupLog "Test-Path result: $pathExists" -Level Debug
            }
            catch {
                Write-SetupLog "ERROR: Test-Path failed!" -Level Error
                Write-SetupLog "Test-Path error: $_" -Level Error
                Write-SetupLog "Error type: $($_.Exception.GetType().FullName)" -Level Error
                throw
            }
            
            if (-not $pathExists) {
                Write-SetupLog "ERROR: Script not found at path: $CustomInstallScript" -Level Error
                Write-SetupLog "Current directory: $(Get-Location)" -Level Error
                Write-SetupLog "Directory contents:" -Level Error
                Get-ChildItem -Path (Split-Path $CustomInstallScript -Parent -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-SetupLog "  $_" -Level Error
                }
                throw "Custom install script not found: $CustomInstallScript"
            }
            
            Write-SetupLog "Running custom install script: $CustomInstallScript" -Level Info
            
            # Enhanced debugging
            Write-SetupLog "CUSTOM Script Debug Information:" -Level Debug
            Write-SetupLog "  Script Path: $CustomInstallScript" -Level Debug
            Write-SetupLog "  Script Exists: $(Test-Path $CustomInstallScript)" -Level Debug
            Write-SetupLog "  Current Directory: $(Get-Location)" -Level Debug
            Write-SetupLog "  PSScriptRoot: $PSScriptRoot" -Level Debug
            Write-SetupLog "  Module PSScriptRoot: $script:PSScriptRoot" -Level Debug
            Write-SetupLog "  Environment PATH: $env:PATH" -Level Debug
            Write-SetupLog "  Node.js in PATH: $($env:PATH -match 'nodejs')" -Level Debug
            Write-SetupLog "  npm location: $(Get-Command npm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)" -Level Debug
            
            try {
                # Ensure we're in the correct directory
                $scriptDir = Split-Path $CustomInstallScript -Parent
                Write-SetupLog "  Script Directory: $scriptDir" -Level Debug
                Write-SetupLog "  Changing to script directory..." -Level Debug
                Push-Location $scriptDir
                
                try {
                    Write-SetupLog "  Current directory after push: $(Get-Location)" -Level Debug
                    Write-SetupLog "  About to execute: & '$CustomInstallScript'" -Level Debug
                    
                    # Add pre-execution validation
                    $scriptContent = Get-Content $CustomInstallScript -Raw -ErrorAction SilentlyContinue
                    if ($scriptContent) {
                        Write-SetupLog "  Script size: $($scriptContent.Length) bytes" -Level Debug
                        Write-SetupLog "  Script first line: $($scriptContent.Split("`n")[0])" -Level Debug
                    }
                    
                    & $CustomInstallScript
                    Write-SetupLog "  Script execution completed" -Level Debug
                } 
                catch {
                    Write-SetupLog "ERROR: Script execution failed!" -Level Error
                    Write-SetupLog "  Error message: $_" -Level Error
                    Write-SetupLog "  Exception type: $($_.Exception.GetType().FullName)" -Level Error
                    Write-SetupLog "  Target object: $($_.TargetObject)" -Level Error
                    Write-SetupLog "  InvocationInfo:" -Level Error
                    Write-SetupLog ($_.InvocationInfo | Format-List | Out-String) -Level Error
                    throw
                }
                finally {
                    Write-SetupLog "  Restoring original directory..." -Level Debug
                    Pop-Location
                    Write-SetupLog "  Current directory after pop: $(Get-Location)" -Level Debug
                }
                return
            } 
            catch {
                Write-SetupLog "Custom script execution error (outer catch):" -Level Error
                Write-SetupLog "  Error: $_" -Level Error
                Write-SetupLog "  Error Type: $($_.Exception.GetType().FullName)" -Level Error
                Write-SetupLog "  Exception details:" -Level Error
                Write-SetupLog ($_.Exception | Format-List * -Force | Out-String) -Level Error
                throw "Custom install script failed: $_"
            }
        }
        
        'MSI_ZIP' {
            Write-SetupLog "MSI_ZIP installer type - extracting MSI from ZIP" -Level Debug
            
            # Create temp extraction path
            $extractPath = Join-Path $env:TEMP "msi_extract_$(Get-Random)"
            New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
            
            try {
                # Extract ZIP file
                Write-SetupLog "Extracting ZIP: $InstallerPath to $extractPath" -Level Debug
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($InstallerPath, $extractPath)
                
                # Find MSI file
                $msiFiles = Get-ChildItem -Path $extractPath -Filter "*.msi" -Recurse
                if (-not $msiFiles) {
                    throw "No MSI file found in ZIP archive"
                }
                
                # Use the first (or largest) MSI file
                $msiFile = $msiFiles | Sort-Object Length -Descending | Select-Object -First 1
                Write-SetupLog "Found MSI: $($msiFile.Name) - $([math]::Round($msiFile.Length / 1MB, 2)) MB" -Level Debug
                
                # Install the MSI
                $msiArgs = @("/i", "`"$($msiFile.FullName)`"") + $Arguments
                Write-SetupLog "Running msiexec with args: $($msiArgs -join ' ')" -Level Debug
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
                
                # Handle MSI error codes
                if ($process.ExitCode -eq 1603) {
                    Write-SetupLog "MSI Error 1603 detected - checking if software was installed anyway" -Level Warning
                    Start-Sleep -Seconds 5
                }
            }
            finally {
                # Cleanup extraction directory
                if (Test-Path $extractPath) {
                    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-SetupLog "Cleaned up extraction directory" -Level Debug
                }
            }
        }
    }
    
    # Only check exit code if we have a process and it has exited
    if ($process -and $process.HasExited) {
        if ($process.ExitCode -ne 0) {
            # For MSI installs, check if software was actually installed despite error code
            if ($InstallType -in @('MSI', 'MSI_ZIP') -and ($process.ExitCode -eq 1603 -or $process.ExitCode -eq 3010)) {
                Write-SetupLog "MSI returned code $($process.ExitCode), checking if software was installed..." -Level Warning
                # Give it a moment to complete
                Start-Sleep -Seconds 2
                # Don't throw error yet - let the validation check handle it
            }
            else {
                throw "Installation failed with exit code: $($process.ExitCode)"
            }
        }
    }
    
    Write-SetupLog "Installation completed successfully" -Level Success
}
#endregion

#region Configuration Functions
function Get-SoftwareConfiguration {
    <#
    .SYNOPSIS
        Loads software configuration from JSON file
    .DESCRIPTION
        Reads and parses the software configuration file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = $script:ConfigPath
    )
    
    if (-not (Test-Path $ConfigFile)) {
        throw "Configuration file not found: $ConfigFile"
    }
    
    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        Write-SetupLog "Loaded configuration from: $ConfigFile" -Level Debug
        return $config
    }
    catch {
        throw "Failed to parse configuration file: $_"
    }
}
#endregion

#region Parallel Execution Functions
function Start-ParallelInstallation {
    <#
    .SYNOPSIS
        Manages parallel installation of multiple software packages
    .DESCRIPTION
        Uses PowerShell jobs to install multiple packages simultaneously
    .PARAMETER Installations
        Array of installation configurations
    .PARAMETER MaxConcurrency
        Maximum number of concurrent installations (default: 4)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxConcurrency = 4,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )
    
    $jobs = @()
    $completed = @()
    $failed = @()
    $skipped = @()
    $running = @{}
    $pending = $Installations.Clone()
    
    Write-SetupLog "Starting parallel installation of $($Installations.Count) packages (max concurrency: $MaxConcurrency)" -Level Info
    
    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        # Start new jobs if under concurrency limit
        while ($running.Count -lt $MaxConcurrency -and $pending.Count -gt 0) {
            $installation = $pending[0]
            
            # Remove from pending array immediately to prevent reprocessing
            if ($pending.Count -gt 1) {
                $pending = $pending[1..($pending.Count - 1)]
            } else {
                $pending = @()
            }
            
            # Skip if validation enabled and already installed
            if (-not $SkipValidation) {
                $validationParams = @{
                    Name = $installation.Name
                }
                
                if ($installation.RegistryName) {
                    $validationParams['RegistryName'] = $installation.RegistryName
                }
                
                if ($installation.ExecutablePath) {
                    $validationParams['ExecutablePath'] = $installation.ExecutablePath
                }
                
                if ($installation.MinimumVersion) {
                    $validationParams['MinimumVersion'] = $installation.MinimumVersion
                }
                
                if (Test-SoftwareInstalled @validationParams) {
                    Write-SetupLog "$($installation.Name) is already installed - skipping" -Level Info
                    $skipped += $installation
                    continue
                }
            }
            
            Write-SetupLog "Starting installation job for: $($installation.Name)" -Level Info
            
            # Double-check if software is already installed before creating job
            $revalidationParams = @{
                Name = $installation.Name
            }
            
            if ($installation.RegistryName) {
                $revalidationParams['RegistryName'] = $installation.RegistryName
            }
            
            if ($installation.ExecutablePath) {
                $revalidationParams['ExecutablePath'] = $installation.ExecutablePath
            }
            
            if ($installation.MinimumVersion) {
                $revalidationParams['MinimumVersion'] = $installation.MinimumVersion
            }
            
            if (Test-SoftwareInstalled @revalidationParams) {
                Write-SetupLog "$($installation.Name) is already installed - skipping job creation" -Level Info
                $skipped += $installation
                continue
            }
            
            $job = Start-Job -ScriptBlock {
                param($ModulePath, $Installation)
                
                Import-Module $ModulePath -Force
                
                try {
                    if ($Installation.InstallType -eq 'NPM') {
                        # Handle NPM package installation
                        $installerParams = @{
                            InstallType = 'NPM'
                            NpmPackage = $Installation.npmPackage
                        }
                        
                        if ($Installation.npmInstallArgs) {
                            $installerParams['NpmInstallArgs'] = $Installation.npmInstallArgs
                        }
                        
                        Invoke-SetupInstaller @installerParams
                        
                        # Run post-install command if provided
                        if ($Installation.postInstallCommand) {
                            Write-SetupLog "Running post-install command: $($Installation.postInstallCommand)" -Level Debug
                            Invoke-Expression $Installation.postInstallCommand
                        }
                    }
                    elseif ($Installation.InstallType -eq 'CUSTOM') {
                        # Handle custom install script
                        if (-not $Installation.customInstallScript) {
                            throw "Custom install script path is required for CUSTOM install type"
                        }
                        
                        $scriptPath = if ([System.IO.Path]::IsPathRooted($Installation.customInstallScript)) {
                            $Installation.customInstallScript
                        } else {
                            Join-Path $PSScriptRoot $Installation.customInstallScript
                        }
                        
                        $installerParams = @{
                            InstallType = 'CUSTOM'
                            CustomInstallScript = $scriptPath
                        }
                        
                        Invoke-SetupInstaller @installerParams
                    }
                    else {
                        # Download installer
                        $installerPath = Join-Path $env:TEMP "$($Installation.Name)_installer$($Installation.InstallerExtension)"
                        Start-SetupDownload -Url $Installation.DownloadUrl -Destination $installerPath
                        
                        # Run installer
                        Invoke-SetupInstaller -InstallerPath $installerPath -Arguments $Installation.InstallArguments -InstallType $Installation.InstallType
                    }
                    
                    # Validate installation (skip for NPM/CUSTOM packages without validation params)
                    if (($Installation.InstallType -ne 'NPM' -and $Installation.InstallType -ne 'CUSTOM') -or $Installation.RegistryName -or $Installation.ExecutablePath) {
                        $validationParams = @{
                            Name = $Installation.Name
                        }
                        
                        if ($Installation.RegistryName) {
                            $validationParams['RegistryName'] = $Installation.RegistryName
                        }
                        
                        if ($Installation.ExecutablePath) {
                            $validationParams['ExecutablePath'] = $Installation.ExecutablePath
                        }
                        
                        if ($Installation.MinimumVersion) {
                            $validationParams['MinimumVersion'] = $Installation.MinimumVersion
                        }
                        
                        if (Test-SoftwareInstalled @validationParams) {
                            return @{
                                Success = $true
                                Name = $Installation.Name
                                Message = "Installation completed successfully"
                            }
                        }
                        else {
                            throw "Post-installation validation failed"
                        }
                    }
                    else {
                        # For NPM/CUSTOM packages without validation, assume success
                        $message = if ($Installation.InstallType -eq 'NPM') { 
                            "NPM package installed successfully" 
                        } else { 
                            "Custom installation completed successfully" 
                        }
                        return @{
                            Success = $true
                            Name = $Installation.Name
                            Message = $message
                        }
                    }
                }
                catch {
                    return @{
                        Success = $false
                        Name = $Installation.Name
                        Message = $_.Exception.Message
                    }
                }
                finally {
                    # Cleanup
                    if ((Test-Path variable:installerPath) -and (Test-Path $installerPath)) {
                        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                    }
                }
            } -ArgumentList (Join-Path $PSScriptRoot "SetupLabCore.psm1"), $installation
            
            $running[$job.Id] = @{
                Job = $job
                Installation = $installation
                StartTime = Get-Date
            }
        }
        
        # Check for completed jobs and timeouts
        $completedJobs = $running.Values | Where-Object { $_.Job.State -ne 'Running' }
        
        # Check for jobs that have been running too long (more than 2 minutes)
        $longRunningJobs = $running.Values | Where-Object { 
            $_.Job.State -eq 'Running' -and 
            ((Get-Date) - $_.StartTime).TotalMinutes -gt 2 
        }
        
        foreach ($longRunningJob in $longRunningJobs) {
            Write-SetupLog "$($longRunningJob.Installation.Name) - Installation timed out after 2 minutes, stopping job" -Level Warning
            Stop-Job -Job $longRunningJob.Job -ErrorAction SilentlyContinue
            $longRunningJob.Job.State = 'Stopped'
            $completedJobs += $longRunningJob
        }
        
        foreach ($jobInfo in $completedJobs) {
            $result = Receive-Job -Job $jobInfo.Job
            Remove-Job -Job $jobInfo.Job
            
            $duration = ((Get-Date) - $jobInfo.StartTime).ToString("mm\:ss")
            
            # Handle timeout cases
            if ($jobInfo.Job.State -eq 'Stopped') {
                Write-SetupLog "$($jobInfo.Installation.Name) - Failed: Installation timed out (Duration: $duration)" -Level Error
                $failed += $jobInfo.Installation
            }
            elseif ($result -and $result.Success) {
                Write-SetupLog "$($result.Name) - $($result.Message) (Duration: $duration)" -Level Success
                $completed += $jobInfo.Installation
            }
            else {
                $errorMsg = if ($result) { $result.Message } else { "Job completed without result" }
                Write-SetupLog "$($jobInfo.Installation.Name) - Failed: $errorMsg (Duration: $duration)" -Level Error
                $failed += $jobInfo.Installation
            }
            
            $running.Remove($jobInfo.Job.Id)
        }
        
        # Brief pause to prevent CPU spinning
        Start-Sleep -Milliseconds 500
    }
    
    # Summary
    Write-SetupLog (("=" * 60)) -Level Info
    Write-SetupLog "Installation Summary:" -Level Info
    Write-SetupLog "  Completed: $($completed.Count)" -Level Success
    Write-SetupLog "  Failed: $($failed.Count)" -Level $(if ($failed.Count -gt 0) { 'Error' } else { 'Info' })
    Write-SetupLog "  Skipped: $($skipped.Count)" -Level Info
    Write-SetupLog (("=" * 60)) -Level Info
    
    return @{
        Completed = $completed
        Failed = $failed
        Skipped = $skipped
    }
}

function Start-SerialInstallation {
    <#
    .SYNOPSIS
        Manages serial installation of multiple software packages
    .DESCRIPTION
        Installs packages one by one in sequence for better stability
    .PARAMETER Installations
        Array of installation configurations
    .PARAMETER SkipValidation
        Skip pre-installation validation checks
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Installations,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )
    
    $completed = @()
    $failed = @()
    $skipped = @()
    $totalCount = $Installations.Count
    $currentIndex = 0
    
    Write-SetupLog "Starting serial installation of $totalCount packages" -Level Info
    Write-SetupLog (("=" * 60)) -Level Info
    
    foreach ($installation in $Installations) {
        $currentIndex++
        $progressPercent = [int](($currentIndex / $totalCount) * 100)
        
        Write-SetupLog "" -Level Info
        Write-SetupLog "[$currentIndex/$totalCount] Installing: $($installation.Name)" -Level Info
        Write-Progress -Activity "Installing Software" -Status "$($installation.Name)" -PercentComplete $progressPercent
        
        # Skip if validation enabled and already installed
        if (-not $SkipValidation) {
            $validationParams = @{
                Name = $installation.Name
            }
            
            if ($installation.RegistryName) {
                $validationParams['RegistryName'] = $installation.RegistryName
            }
            
            if ($installation.ExecutablePath) {
                $validationParams['ExecutablePath'] = $installation.ExecutablePath
            }
            
            if ($installation.MinimumVersion) {
                $validationParams['MinimumVersion'] = $installation.MinimumVersion
            }
            
            if (Test-SoftwareInstalled @validationParams) {
                Write-SetupLog "$($installation.Name) is already installed - skipping" -Level Info
                $skipped += $installation
                continue
            }
        }
        
        try {
            if ($installation.InstallType -eq 'NPM') {
                # Handle NPM package installation
                $installerParams = @{
                    InstallType = 'NPM'
                    NpmPackage = $installation.npmPackage
                }
                
                if ($installation.npmInstallArgs) {
                    $installerParams['NpmInstallArgs'] = $installation.npmInstallArgs
                }
                
                Invoke-SetupInstaller @installerParams
                
                # Run post-install command if provided
                if ($installation.postInstallCommand) {
                    Write-SetupLog "Running post-install command: $($installation.postInstallCommand)" -Level Debug
                    Invoke-Expression $installation.postInstallCommand
                }
            }
            elseif ($installation.InstallType -eq 'CUSTOM') {
                # Handle custom install script
                if (-not $installation.customInstallScript) {
                    throw "Custom install script path is required for CUSTOM install type"
                }
                
                # Enhanced debugging for script path resolution
                Write-SetupLog "CUSTOM Install Path Resolution:" -Level Debug
                Write-SetupLog "  Original Path: '$($installation.customInstallScript)'" -Level Debug
                Write-SetupLog "  Is Rooted: $([System.IO.Path]::IsPathRooted($installation.customInstallScript))" -Level Debug
                Write-SetupLog "  PSScriptRoot: '$PSScriptRoot'" -Level Debug
                Write-SetupLog "  PSScriptRoot is null: $($null -eq $PSScriptRoot)" -Level Debug
                
                $scriptPath = if ([System.IO.Path]::IsPathRooted($installation.customInstallScript)) {
                    $installation.customInstallScript
                } else {
                    if (-not $PSScriptRoot) {
                        # Fallback: use module directory
                        $module = Get-Module SetupLabCore
                        if ($module) {
                            $moduleDir = Split-Path $module.Path -Parent
                            Write-SetupLog "  PSScriptRoot is empty, using module directory: $moduleDir" -Level Debug
                            Join-Path $moduleDir $installation.customInstallScript
                        } else {
                            # Module not loaded, use current directory as fallback
                            $currentDir = Get-Location
                            Write-SetupLog "  PSScriptRoot empty and module not loaded, using current dir: $currentDir" -Level Debug
                            Join-Path $currentDir $installation.customInstallScript
                        }
                    } else {
                        Join-Path $PSScriptRoot $installation.customInstallScript
                    }
                }
                
                Write-SetupLog "  Resolved Path: $scriptPath" -Level Debug
                Write-SetupLog "  Path Exists: $(Test-Path $scriptPath)" -Level Debug
                
                # Additional validation before passing to installer
                if ([string]::IsNullOrWhiteSpace($scriptPath)) {
                    throw "Script path is empty after resolution"
                }
                
                $installerParams = @{
                    InstallType = 'CUSTOM'
                    CustomInstallScript = $scriptPath
                }
                
                Write-SetupLog "  Passing CustomInstallScript: $($installerParams.CustomInstallScript)" -Level Debug
                
                Invoke-SetupInstaller @installerParams
            }
            else {
                # Handle dynamic URL if needed
                $downloadUrl = $installation.DownloadUrl
                
                if ($installation.dynamicUrl -and $installation.Name -eq "Python") {
                    Write-SetupLog "Fetching dynamic URL for Python..." -Level Debug
                    
                    # Load the Python URL fetcher
                    $pythonFetcherPath = Join-Path $PSScriptRoot "Get-LatestPythonUrl.ps1"
                    if (Test-Path $pythonFetcherPath) {
                        . $pythonFetcherPath
                        $downloadUrl = Get-LatestPythonUrl
                        Write-SetupLog "Dynamic Python URL: $downloadUrl" -Level Debug
                    } else {
                        Write-SetupLog "Python URL fetcher not found, using fallback" -Level Warning
                        $downloadUrl = "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe"
                    }
                }
                
                # Download installer
                $installerPath = Join-Path $env:TEMP "$($installation.Name)_installer$($installation.InstallerExtension)"
                Write-SetupLog "Downloading installer to: $installerPath" -Level Debug
                Start-SetupDownload -Url $downloadUrl -Destination $installerPath
                
                # Run installer
                Invoke-SetupInstaller -InstallerPath $installerPath -Arguments $installation.InstallArguments -InstallType $installation.InstallType
            }
            
            # Validate installation (skip for NPM/CUSTOM packages without validation params)
            if (($installation.InstallType -ne 'NPM' -and $installation.InstallType -ne 'CUSTOM') -or $installation.RegistryName -or $installation.ExecutablePath) {
                $validationParams = @{
                    Name = $installation.Name
                }
                
                if ($installation.RegistryName) {
                    $validationParams['RegistryName'] = $installation.RegistryName
                }
                
                if ($installation.ExecutablePath) {
                    $validationParams['ExecutablePath'] = $installation.ExecutablePath
                }
                
                if ($installation.MinimumVersion) {
                    $validationParams['MinimumVersion'] = $installation.MinimumVersion
                }
                
                if (Test-SoftwareInstalled @validationParams) {
                    Write-SetupLog "$($installation.Name) installed successfully" -Level Success
                    $completed += $installation
                }
                else {
                    throw "Post-installation validation failed"
                }
            }
            else {
                # For NPM/CUSTOM packages without validation, assume success
                Write-SetupLog "$($installation.Name) installation completed" -Level Success
                $completed += $installation
            }
        }
        catch {
            Write-SetupLog "Failed to install $($installation.Name): $_" -Level Error
            Write-SetupLog "Error Type: $($_.Exception.GetType().FullName)" -Level Error
            Write-SetupLog "Target Site: $($_.Exception.TargetSite)" -Level Error
            Write-SetupLog "Inner Exception: $($_.Exception.InnerException)" -Level Error
            $failed += $installation
        }
    }
    
    Write-Progress -Activity "Installing Software" -Completed
    
    Write-SetupLog "" -Level Info
    Write-SetupLog (("=" * 60)) -Level Info
    Write-SetupLog "Installation Summary:" -Level Info
    Write-SetupLog "  Completed: $($completed.Count)" -Level Success
    Write-SetupLog "  Failed: $($failed.Count)" -Level $(if ($failed.Count -gt 0) { 'Error' } else { 'Info' })
    Write-SetupLog "  Skipped: $($skipped.Count)" -Level Info
    Write-SetupLog (("=" * 60)) -Level Info
    
    return @{
        Completed = $completed
        Failed = $failed
        Skipped = $skipped
    }
}
#endregion

#region Export Module Members
Export-ModuleMember -Function @(
    'Write-SetupLog',
    'Test-AdminPrivileges',
    'Request-AdminElevation',
    'Start-SetupDownload',
    'Test-SoftwareInstalled',
    'Get-InstalledSoftwareVersion',
    'Invoke-SetupInstaller',
    'Get-SoftwareConfiguration',
    'Start-ParallelInstallation',
    'Start-SerialInstallation'
)
#endregion

