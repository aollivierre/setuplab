#Requires -Version 5.1
<#
.SYNOPSIS
    Web launcher script for SetupLab - Downloads and executes SetupLab from GitHub
.DESCRIPTION
    This script downloads the SetupLab components from GitHub to a temporary directory
    and executes the main script. This allows running SetupLab directly from a URL
    without manually cloning the repository.
.PARAMETER BaseUrl
    Base URL for the GitHub raw content (default: SetupLab main branch)
.PARAMETER SkipValidation
    Skip pre-installation validation checks and install all enabled software
.PARAMETER MaxConcurrency
    Maximum number of concurrent installations (default: 4)
.PARAMETER Categories
    Comma-separated list of categories to install (default: all enabled categories)
.PARAMETER Software
    Comma-separated list of specific software names to install
.PARAMETER ListSoftware
    List all available software without installing
.PARAMETER ConfigFile
    Name of configuration file to download (default: software-config.json)
.EXAMPLE
    # Execute directly from web:
    iex (irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1')
.EXAMPLE
    # Execute with parameters:
    & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1'))) -SkipValidation -MaxConcurrency 6
.EXAMPLE
    # Download and execute manually:
    $launcher = "$env:TEMP\SetupLab-WebLauncher.ps1"
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLab-WebLauncher.ps1' -OutFile $launcher
    & $launcher -Categories "Development,Browsers"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrency = 4,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Categories = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$Software = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$ListSoftware,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "software-config.json"
)

#region Functions
function Write-WebLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Info" { "White" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-Url {
    param([string]$Url)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 10
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-WebLog "Downloading: $Url" -Level Info
        
        # Add cache-busting parameter
        $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
        $separator = if ($Url.Contains("?")) { "&" } else { "?" }
        $cacheBustUrl = "$Url$separator" + "nocache=$timestamp"
        
        # Ensure TLS 1.2 is enabled
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Download with no-cache headers
        $headers = @{
            'Cache-Control' = 'no-cache'
            'Pragma' = 'no-cache'
        }
        
        # Download the file
        Invoke-WebRequest -Uri $cacheBustUrl -OutFile $OutputPath -UseBasicParsing -Headers $headers -ErrorAction Stop
        
        if (Test-Path $OutputPath) {
            Write-WebLog "Successfully downloaded to: $OutputPath" -Level Success
            return $true
        }
        else {
            Write-WebLog "Download appeared to succeed but file not found: $OutputPath" -Level Error
            return $false
        }
    }
    catch {
        Write-WebLog "Failed to download $Url : $_" -Level Error
        return $false
    }
}
#endregion

#region Main Execution
Write-WebLog "SetupLab Web Launcher" -Level Info
Write-WebLog (("=" * 60)) -Level Info

# Ensure BaseUrl doesn't end with a slash
$BaseUrl = $BaseUrl.TrimEnd('/')

# Create temporary directory
$tempDir = Join-Path $env:TEMP "SetupLab_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-WebLog "Creating temporary directory: $tempDir" -Level Info

try {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}
catch {
    Write-WebLog "Failed to create temporary directory: $_" -Level Error
    exit 1
}

# Define files to download
$filesToDownload = @(
    @{
        Name = "main.ps1"
        Url = "$BaseUrl/main.ps1"
        Required = $true
    },
    @{
        Name = "SetupLabCore.psm1"
        Url = "$BaseUrl/SetupLabCore.psm1"
        Required = $true
    },
    @{
        Name = $ConfigFile
        Url = "$BaseUrl/$ConfigFile"
        Required = $true
    },
    @{
        Name = "DarkTheme/Set-WindowsTheme.ps1"
        Url = "$BaseUrl/DarkTheme/Set-WindowsTheme.ps1"
        Required = $true
        SubDir = "DarkTheme"
    },
    @{
        Name = "Set-DNSServers.ps1"
        Url = "$BaseUrl/Set-DNSServers.ps1"
        Required = $true
    },
    @{
        Name = "Rename-Computer.ps1"
        Url = "$BaseUrl/Rename-Computer.ps1"
        Required = $true
    },
    @{
        Name = "Join-Domain.ps1"
        Url = "$BaseUrl/Join-Domain.ps1"
        Required = $true
    },
    @{
        Name = "Configure-WindowsTerminal.ps1"
        Url = "$BaseUrl/Configure-WindowsTerminal.ps1"
        Required = $true
    },
    @{
        Name = "Terminal/settings.json"
        Url = "$BaseUrl/Terminal/settings.json"
        Required = $true
        SubDir = "Terminal"
    },
    @{
        Name = "Terminal/LaunchPowerShellAsSystem.ps1"
        Url = "$BaseUrl/Terminal/LaunchPowerShellAsSystem.ps1"
        Required = $true
        SubDir = "Terminal"
    }
)

# Download all required files
$downloadSuccess = $true
foreach ($file in $filesToDownload) {
    # Handle subdirectories
    if ($file.SubDir) {
        $subDirPath = Join-Path $tempDir $file.SubDir
        if (-not (Test-Path $subDirPath)) {
            New-Item -ItemType Directory -Path $subDirPath -Force | Out-Null
        }
        $outputPath = Join-Path $tempDir $file.Name
    }
    else {
        $outputPath = Join-Path $tempDir $file.Name
    }
    
    if (-not (Download-File -Url $file.Url -OutputPath $outputPath)) {
        if ($file.Required) {
            Write-WebLog "Failed to download required file: $($file.Name)" -Level Error
            $downloadSuccess = $false
            break
        }
        else {
            Write-WebLog "Failed to download optional file: $($file.Name), continuing..." -Level Warning
        }
    }
}

if (-not $downloadSuccess) {
    Write-WebLog "Failed to download all required files. Cleaning up..." -Level Error
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-WebLog "" -Level Info
Write-WebLog "All required files downloaded successfully" -Level Success
Write-WebLog "" -Level Info

# Build parameters for main.ps1
$mainScriptPath = Join-Path $tempDir "main.ps1"
$mainParams = @{}

if ($SkipValidation) { $mainParams['SkipValidation'] = $true }
if ($PSBoundParameters.ContainsKey('MaxConcurrency')) { $mainParams['MaxConcurrency'] = $MaxConcurrency }
if ($Categories.Count -gt 0) { $mainParams['Categories'] = $Categories }
if ($Software.Count -gt 0) { $mainParams['Software'] = $Software }
if ($ListSoftware) { $mainParams['ListSoftware'] = $true }
if ($PSBoundParameters.ContainsKey('ConfigFile')) { $mainParams['ConfigFile'] = $ConfigFile }

# Execute main.ps1
try {
    Write-WebLog "Executing SetupLab main script..." -Level Info
    Write-WebLog "" -Level Info
    
    # Change to temp directory to ensure relative paths work
    Push-Location $tempDir
    
    # Execution policy is not needed when using -File parameter
    
    # Execute the script
    & $mainScriptPath @mainParams
    
    # Return to original directory
    Pop-Location
}
catch {
    Pop-Location
    Write-WebLog "Error executing main script: $_" -Level Error
    exit 1
}
finally {
    # Cleanup temporary directory
    Write-WebLog "" -Level Info
    Write-WebLog "Cleaning up temporary files..." -Level Info
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-WebLog "SetupLab Web Launcher completed" -Level Success
#endregion