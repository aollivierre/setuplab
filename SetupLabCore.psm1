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
    $logMessage = if ($Message) { "[$timestamp] [$Level] $Message" } else { "" }
    $logFilePath = Join-Path $script:LogPath $LogFile
    
    # Write to log file
    Add-Content -Path $logFilePath -Value $logMessage -Force
    
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
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $webClient.DownloadFile($Url, $Destination)
                $success = $true
                Write-SetupLog "Download completed using WebClient" -Level Success
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
    
    # Check executable path first if provided
    if ($ExecutablePath -and (Test-Path $ExecutablePath)) {
        if ($MinimumVersion) {
            try {
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
                Write-SetupLog "Could not determine version for $Name" -Level Warning
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
        [ValidateSet('MSI', 'EXE', 'MSIX', 'NPM', 'Auto')]
        [string]$InstallType = 'Auto',
        
        [Parameter(Mandatory = $false)]
        [string]$NpmPackage,
        
        [Parameter(Mandatory = $false)]
        [string[]]$NpmInstallArgs = @()
    )
    
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
        
        # Build npm install command
        $npmArgs = @("install", "-g", $NpmPackage) + $NpmInstallArgs
        
        Write-SetupLog "Running: npm $($npmArgs -join ' ')" -Level Debug
        
        $process = Start-Process -FilePath "npm" -ArgumentList $npmArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            throw "NPM installation failed with exit code: $($process.ExitCode)"
        }
        
        Write-SetupLog "NPM package installed successfully" -Level Success
        return
    }
    
    if (-not (Test-Path $InstallerPath)) {
        throw "Installer not found: $InstallerPath"
    }
    
    # Determine install type if Auto
    if ($InstallType -eq 'Auto') {
        $extension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        $InstallType = switch ($extension) {
            '.msi'  { 'MSI' }
            '.msix' { 'MSIX' }
            '.msixbundle' { 'MSIX' }
            default { 'EXE' }
        }
    }
    
    Write-SetupLog "Installing using $InstallType method" -Level Info
    
    switch ($InstallType) {
        'MSI' {
            $msiArgs = @("/i", "`"$InstallerPath`"") + $Arguments
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        }
        
        'MSIX' {
            Add-AppxPackage -Path $InstallerPath -ErrorAction Stop
            return
        }
        
        'EXE' {
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -PassThru
        }
    }
    
    if ($process.ExitCode -ne 0) {
        throw "Installation failed with exit code: $($process.ExitCode)"
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
            $pending = $pending[1..($pending.Count - 1)]
            
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
                    else {
                        # Download installer
                        $installerPath = Join-Path $env:TEMP "$($Installation.Name)_installer$($Installation.InstallerExtension)"
                        Start-SetupDownload -Url $Installation.DownloadUrl -Destination $installerPath
                        
                        # Run installer
                        Invoke-SetupInstaller -InstallerPath $installerPath -Arguments $Installation.InstallArguments -InstallType $Installation.InstallType
                    }
                    
                    # Validate installation (skip for NPM packages without validation params)
                    if ($Installation.InstallType -ne 'NPM' -or $Installation.RegistryName -or $Installation.ExecutablePath) {
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
                        # For NPM packages without validation, assume success
                        return @{
                            Success = $true
                            Name = $Installation.Name
                            Message = "NPM package installed successfully"
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
        
        # Check for completed jobs
        $completedJobs = $running.Values | Where-Object { $_.Job.State -ne 'Running' }
        
        foreach ($jobInfo in $completedJobs) {
            $result = Receive-Job -Job $jobInfo.Job
            Remove-Job -Job $jobInfo.Job
            
            $duration = ((Get-Date) - $jobInfo.StartTime).ToString("mm\:ss")
            
            if ($result.Success) {
                Write-SetupLog "$($result.Name) - $($result.Message) (Duration: $duration)" -Level Success
                $completed += $jobInfo.Installation
            }
            else {
                Write-SetupLog "$($result.Name) - Failed: $($result.Message) (Duration: $duration)" -Level Error
                $failed += $jobInfo.Installation
            }
            
            $running.Remove($jobInfo.Job.Id)
        }
        
        # Brief pause to prevent CPU spinning
        Start-Sleep -Milliseconds 500
    }
    
    # Summary
    Write-SetupLog ("=" * 60) -Level Info
    Write-SetupLog "Installation Summary:" -Level Info
    Write-SetupLog "  Completed: $($completed.Count)" -Level Success
    Write-SetupLog "  Failed: $($failed.Count)" -Level $(if ($failed.Count -gt 0) { 'Error' } else { 'Info' })
    Write-SetupLog "  Skipped: $($skipped.Count)" -Level Info
    Write-SetupLog ("=" * 60) -Level Info
    
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
    'Start-ParallelInstallation'
)
#endregion