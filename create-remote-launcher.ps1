# Creates a launcher script that can be run on the remote machine
# This avoids cross-domain issues by running locally on the target

$remoteSetupScript = @'
# SetupLab Remote Launcher
# This script downloads and runs the SetupLab from a web server or file share

param(
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = "\\198.18.1.110\c$\code\setuplab",
    
    [Parameter(Mandatory = $false)]
    [string]$LocalPath = "C:\Temp\SetupLab",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseWebDownload
)

# Ensure running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "SetupLab Remote Launcher" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

# Create local directory
if (-not (Test-Path $LocalPath)) {
    New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
}

if ($UseWebDownload) {
    # Download from web server
    Write-Host "Downloading SetupLab from web..." -ForegroundColor Yellow
    $webUrl = "https://raw.githubusercontent.com/your-repo/setuplab/main/"
    
    # Download main files
    $filesToDownload = @(
        "main.ps1",
        "SetupLabCore.psm1",
        "SetupLabLogging.psm1",
        "software-config.json"
    )
    
    foreach ($file in $filesToDownload) {
        try {
            $url = "$webUrl$file"
            $destination = Join-Path $LocalPath $file
            Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
            Write-Host "  Downloaded: $file" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to download $file: $_" -ForegroundColor Red
        }
    }
} else {
    # Copy from network share with credentials
    Write-Host "Enter credentials for accessing the source share" -ForegroundColor Yellow
    $cred = Get-Credential -Message "Enter credentials for $SourcePath"
    
    try {
        # Map network drive temporarily
        $drive = "Z:"
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $SourcePath -Credential $cred -ErrorAction Stop
        
        Write-Host "Copying files from $SourcePath..." -ForegroundColor Yellow
        
        # Copy all files
        $files = Get-ChildItem -Path "${drive}\" -File
        foreach ($file in $files) {
            Copy-Item -Path $file.FullName -Destination $LocalPath -Force
            Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
        }
        
        # Copy subdirectories
        $directories = @("DarkTheme", "Terminal", "Archive")
        foreach ($dir in $directories) {
            if (Test-Path "${drive}\$dir") {
                Copy-Item -Path "${drive}\$dir" -Destination $LocalPath -Recurse -Force
                Write-Host "  Copied directory: $dir" -ForegroundColor Green
            }
        }
        
        # Remove temporary drive
        Remove-PSDrive -Name "Z" -Force
        
    } catch {
        Write-Host "Failed to copy files: $_" -ForegroundColor Red
        exit 1
    }
}

# Run the setup
Write-Host "`nStarting SetupLab installation..." -ForegroundColor Yellow
Write-Host "Log files will be in: C:\ProgramData\SetupLab\Logs" -ForegroundColor Cyan

$mainScript = Join-Path $LocalPath "main.ps1"
if (Test-Path $mainScript) {
    Set-Location $LocalPath
    & $mainScript -SkipValidation
} else {
    Write-Host "Main script not found at: $mainScript" -ForegroundColor Red
}
'@

# Save the launcher script
$launcherPath = "C:\code\setuplab\SetupLab-RemoteLauncher.ps1"
$remoteSetupScript | Out-File -FilePath $launcherPath -Encoding UTF8 -Force

Write-Host "Remote launcher script created at:" -ForegroundColor Green
Write-Host "  $launcherPath" -ForegroundColor White
Write-Host ""
Write-Host "To use this launcher:" -ForegroundColor Yellow
Write-Host "1. Copy this file to the remote machine (via RDP, USB, etc.)" -ForegroundColor White
Write-Host "2. Run it on the remote machine as administrator" -ForegroundColor White
Write-Host "3. It will download/copy all SetupLab files and run the installation" -ForegroundColor White
Write-Host ""
Write-Host "Alternative: Use the web launcher approach" -ForegroundColor Cyan
Write-Host "  The remote machine can download and run directly from GitHub/web server" -ForegroundColor White