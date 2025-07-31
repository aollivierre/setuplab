# SetupLab Web Launcher - Version 2.0 with Enhanced Cache Busting
# Compatible with iex (irm 'url') execution

param(
    $BaseUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main",
    $SkipValidation = $false,
    $MaxConcurrency = 4,
    $Categories = @(),
    $Software = @(),
    $ListSoftware = $false,
    $ConfigFile = "software-config.json"
)

# Launcher version info
$launcherVersion = "2.0.0"
$launcherDate = "2025-07-31"

# Set execution policy
if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "Execution policy set to Bypass for current process" -ForegroundColor Green
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SetupLab Web Launcher v$launcherVersion ($launcherDate)" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ============================================================" -ForegroundColor DarkGray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Source: $BaseUrl" -ForegroundColor Gray

# Create temp directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempPath = Join-Path $env:TEMP "SetupLab_$timestamp"

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Creating temporary directory: $tempPath" -ForegroundColor Gray
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Required files
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

# Download with aggressive cache busting
$allSuccess = $true
foreach ($file in $filesToDownload) {
    $fileUrl = "$BaseUrl/$($file.Name)"
    $fileDest = Join-Path $tempPath $file.Name
    
    # Create subdirectory if needed
    $destDir = Split-Path $fileDest -Parent
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Downloading: $fileUrl" -ForegroundColor Gray
    
    try {
        # Force fresh download with multiple cache-busting techniques
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $webClient.Headers.Add("Pragma", "no-cache")
        $webClient.Headers.Add("Expires", "0")
        
        # Add timestamp to URL
        $cacheBustUrl = if ($fileUrl.Contains("?")) { 
            "${fileUrl}&cb=${timestamp}" 
        } else { 
            "${fileUrl}?cb=${timestamp}" 
        }
        
        $webClient.DownloadFile($cacheBustUrl, $fileDest)
        $webClient.Dispose()
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Successfully downloaded to: $fileDest" -ForegroundColor Green
        
        # Verify critical files
        if ($file.Name -eq "install-claude-cli.ps1") {
            $content = Get-Content $fileDest -Raw
            if ($content -match 'if \(-not \$currentPath\)') {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [OK] Claude CLI fix verified in downloaded file" -ForegroundColor Green
            } else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WARNING] Claude CLI fix NOT found!" -ForegroundColor Yellow
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] File may be cached. Trying alternate download..." -ForegroundColor Yellow
                
                # Try PowerShell method as fallback
                $response = Invoke-WebRequest -Uri $cacheBustUrl -UseBasicParsing -Headers @{
                    'Cache-Control' = 'no-cache'
                    'Pragma' = 'no-cache'
                }
                [System.IO.File]::WriteAllText($fileDest, $response.Content)
                
                # Check again
                $content = Get-Content $fileDest -Raw
                if ($content -match 'if \(-not \$currentPath\)') {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [OK] Claude CLI fix verified after retry" -ForegroundColor Green
                }
            }
        }
    }
    catch {
        if ($file.Required) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to download required file: $($file.Name)" -ForegroundColor Red
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error: $_" -ForegroundColor Red
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

# Show file sizes and modification times for verification
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] File verification:" -ForegroundColor Cyan
Get-ChildItem -Path $tempPath -Recurse -File | ForEach-Object {
    $size = "{0:N0}" -f $_.Length
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]   $($_.Name) - $size bytes" -ForegroundColor Gray
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Executing SetupLab main script..." -ForegroundColor Yellow
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray

# Build parameters
$params = @{
    ConfigFile = Join-Path $tempPath $ConfigFile
}

if ($SkipValidation) { $params['SkipValidation'] = $true }
if ($MaxConcurrency) { $params['MaxConcurrency'] = $MaxConcurrency }
if ($Categories.Count -gt 0) { $params['Categories'] = $Categories }
if ($Software.Count -gt 0) { $params['Software'] = $Software }
if ($ListSoftware) { $params['ListSoftware'] = $true }

# Execute
& (Join-Path $tempPath "main.ps1") @params

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor Gray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Cleaning up temporary files..." -ForegroundColor Gray
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SetupLab Web Launcher completed" -ForegroundColor Green