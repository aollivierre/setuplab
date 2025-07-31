# Simple SetupLab Web Launcher - Compatible with iex/irm execution
# No CmdletBinding or advanced parameter attributes for compatibility

param(
    $BaseUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main",
    $SkipValidation = $false,
    $MaxConcurrency = 4,
    $Categories = @(),
    $Software = @(),
    $ListSoftware = $false,
    $ConfigFile = "software-config.json"
)

# Set execution policy for current process
if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "Execution policy set to Bypass for current process" -ForegroundColor Green
}

#region Functions
function Write-WebLog {
    param($Message, $Level = "Info")
    
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

function Download-File {
    param($Url, $OutputPath)
    
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
Write-WebLog "SetupLab Web Launcher (Simple Version)" -Level Info
Write-WebLog ("=" * 60) -Level Info

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
        Name = "SetupLabLogging.psm1"
        Url = "$BaseUrl/SetupLabLogging.psm1"
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
    },
    @{
        Name = "Download-Sysinternals.ps1"
        Url = "$BaseUrl/Download-Sysinternals.ps1"
        Required = $true
    },
    @{
        Name = "install-claude-cli.ps1"
        Url = "$BaseUrl/install-claude-cli.ps1"
        Required = $false
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

if ($SkipValidation -eq $true) { $mainParams['SkipValidation'] = $true }
if ($MaxConcurrency -ne 4) { $mainParams['MaxConcurrency'] = $MaxConcurrency }
if ($Categories.Count -gt 0) { $mainParams['Categories'] = $Categories }
if ($Software.Count -gt 0) { $mainParams['Software'] = $Software }
if ($ListSoftware -eq $true) { $mainParams['ListSoftware'] = $true }
if ($ConfigFile -ne "software-config.json") { $mainParams['ConfigFile'] = $ConfigFile }

# Execute main.ps1
try {
    Write-WebLog "Executing SetupLab main script..." -Level Info
    Write-WebLog "" -Level Info
    
    # Change to temp directory to ensure relative paths work
    Push-Location $tempDir
    
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