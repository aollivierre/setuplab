# SetupLab Web Launcher with Version Tracking and Enhanced Cache Busting
# This launcher displays version info and uses timestamp-based cache busting

param(
    $BaseUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main",
    $SkipValidation = $false,
    $MaxConcurrency = 4,
    $Categories = @(),
    $Software = @(),
    $ListSoftware = $false,
    $ConfigFile = "software-config.json"
)

# Version and build info
$launcherVersion = "2.0.0"
$launcherDate = "2025-07-31"

# Set execution policy for current process
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force | Out-Null

# Display version info
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SetupLab Web Launcher v$launcherVersion ($launcherDate)" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ============================================================" -ForegroundColor DarkGray

# Create temp directory with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempPath = Join-Path $env:TEMP "SetupLab_$timestamp"

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Creating temporary directory: $tempPath" -ForegroundColor Gray
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Required files to download with cache-busting parameter
$cacheBuster = "?v=$timestamp"
$filesToDownload = @(
    @{Name = "main.ps1"; Required = $true},
    @{Name = "SetupLabCore.psm1"; Required = $true},
    @{Name = "SetupLabLogging.psm1"; Required = $true},
    @{Name = "software-config.json"; Required = $true},
    @{Name = "DarkTheme/Set-WindowsTheme.ps1"; Required = $false},
    @{Name = "Set-DNSServers.ps1"; Required = $false},
    @{Name = "Rename-Computer.ps1"; Required = $false},
    @{Name = "Join-Domain.ps1"; Required = $false},
    @{Name = "Configure-WindowsTerminal.ps1"; Required = $false},
    @{Name = "Terminal/settings.json"; Required = $false},
    @{Name = "Terminal/LaunchPowerShellAsSystem.ps1"; Required = $false},
    @{Name = "Download-Sysinternals.ps1"; Required = $false},
    @{Name = "install-claude-cli.ps1"; Required = $false}
)

# Download function with cache busting
function Download-FileWithCacheBust {
    param(
        [string]$Url,
        [string]$Destination
    )
    
    try {
        # Add cache buster to URL
        $bustUrl = if ($Url -contains '?') { "$Url&cb=$timestamp" } else { "$Url$cacheBuster" }
        
        # Use different methods to bypass cache
        $headers = @{
            'Cache-Control' = 'no-cache, no-store, must-revalidate'
            'Pragma' = 'no-cache'
            'Expires' = '0'
        }
        
        $response = Invoke-WebRequest -Uri $bustUrl -UseBasicParsing -Headers $headers -ErrorAction Stop
        
        # Ensure directory exists
        $destDir = Split-Path $Destination -Parent
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        # Save content
        [System.IO.File]::WriteAllBytes($Destination, $response.Content)
        
        return $true
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# Download all required files
$allSuccess = $true
foreach ($file in $filesToDownload) {
    $fileUrl = "$BaseUrl/$($file.Name)"
    $fileDest = Join-Path $tempPath $file.Name
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Downloading: $fileUrl" -ForegroundColor Gray
    
    if (Download-FileWithCacheBust -Url $fileUrl -Destination $fileDest) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Successfully downloaded to: $fileDest" -ForegroundColor Green
        
        # Display version info for key files
        if ($file.Name -eq "install-claude-cli.ps1") {
            $content = Get-Content $fileDest -Raw
            if ($content -match 'if \(-not \$currentPath\)') {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ✓ Claude CLI fix detected in downloaded file" -ForegroundColor Green
            } else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ⚠ Claude CLI fix NOT found in downloaded file!" -ForegroundColor Yellow
            }
        }
    } else {
        if ($file.Required) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to download required file: $($file.Name)" -ForegroundColor Red
            $allSuccess = $false
            break
        } else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Warning: Optional file not downloaded: $($file.Name)" -ForegroundColor Yellow
        }
    }
}

if (!$allSuccess) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to download all required files. Exiting..." -ForegroundColor Red
    exit 1
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] All required files downloaded successfully" -ForegroundColor Green
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray

# Add version display to main.ps1
$mainPath = Join-Path $tempPath "main.ps1"
if (Test-Path $mainPath) {
    $mainContent = Get-Content $mainPath -Raw
    
    # Add version info at the beginning
    $versionBlock = @"
# SetupLab Version Information
`$setupLabVersion = @{
    Version = '1.0.0'
    Date = '$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")'
    Source = '$BaseUrl'
    LauncherVersion = '$launcherVersion'
}

Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Version] SetupLab v`$(`$setupLabVersion.Version) - Downloaded: `$(`$setupLabVersion.Date)" -ForegroundColor Cyan
Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Version] Source: `$(`$setupLabVersion.Source)" -ForegroundColor Gray

"@
    
    # Prepend version info to main.ps1
    $updatedContent = $versionBlock + "`n" + $mainContent
    Set-Content -Path $mainPath -Value $updatedContent -Encoding UTF8
}

# Execute SetupLab
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Executing SetupLab main script..." -ForegroundColor Yellow
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray

# Build parameters for main.ps1
$params = @{
    ConfigFile = Join-Path $tempPath $ConfigFile
}

if ($SkipValidation) { $params['SkipValidation'] = $true }
if ($MaxConcurrency) { $params['MaxConcurrency'] = $MaxConcurrency }
if ($Categories.Count -gt 0) { $params['Categories'] = $Categories }
if ($Software.Count -gt 0) { $params['Software'] = $Software }
if ($ListSoftware) { $params['ListSoftware'] = $true }

# Execute main.ps1
& (Join-Path $tempPath "main.ps1") @params

# Cleanup
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Cleaning up temporary files..." -ForegroundColor Gray
# Note: We don't remove temp files immediately to allow for debugging if needed
# They will be cleaned up by Windows temp file cleanup

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SetupLab Web Launcher completed" -ForegroundColor Green