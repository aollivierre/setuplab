#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Downloads and extracts the Sysinternals Suite to Public Desktop with age checking
.DESCRIPTION
    This script downloads the complete Sysinternals Suite from Microsoft,
    extracts it to the Public Desktop (C:\Users\Public\Desktop\Sysinternals),
    making it available for all users, and adds the directory to the system PATH.
    Includes 30-day age check to avoid unnecessary downloads.
.EXAMPLE
    .\Download-Sysinternals-Enhanced.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$SysinternalsPath = Join-Path $PublicDesktop "Sysinternals"
$SysinternalsUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
$AgeCheckFile = Join-Path $SysinternalsPath ".last_updated"
$MaxAgeInDays = 30
#endregion

#region Import Logging Module
$loggingModulePath = Join-Path $PSScriptRoot "SetupLabCore.psm1"
if (Test-Path $loggingModulePath) {
    Import-Module $loggingModulePath -Force
} else {
    # Fallback to simple logging
    function Write-SetupLog {
        param(
            [string]$Message,
            [string]$Level = "Info"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            "Error" { "Red" }
            "Warning" { "Yellow" }
            "Success" { "Green" }
            "Debug" { "Gray" }
            default { "White" }
        }
        
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}
#endregion

#region Functions
function Test-SysinternalsAge {
    <#
    .SYNOPSIS
        Checks if Sysinternals tools are older than specified days
    .DESCRIPTION
        Returns $true if tools need updating (older than MaxAge or not present)
        Returns $false if tools are recent enough
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $SysinternalsPath,
        [string]$AgeFile = $AgeCheckFile,
        [int]$MaxDays = $MaxAgeInDays
    )
    
    Write-SetupLog "Checking Sysinternals age..." -Level Debug
    
    # Check if directory exists
    if (-not (Test-Path $Path)) {
        Write-SetupLog "Sysinternals directory not found - download required" -Level Debug
        return $true
    }
    
    # Check if we have the age check file
    if (-not (Test-Path $AgeFile)) {
        Write-SetupLog "Age check file not found - download required" -Level Debug
        return $true
    }
    
    # Check age
    try {
        $lastUpdated = Get-Content $AgeFile -ErrorAction Stop | Get-Date
        $age = (Get-Date) - $lastUpdated
        
        Write-SetupLog "Sysinternals last updated: $($lastUpdated.ToString('yyyy-MM-dd'))" -Level Debug
        Write-SetupLog "Age: $([int]$age.TotalDays) days" -Level Debug
        
        if ($age.TotalDays -gt $MaxDays) {
            Write-SetupLog "Sysinternals tools are older than $MaxDays days - update required" -Level Info
            return $true
        } else {
            Write-SetupLog "Sysinternals tools are up to date (less than $MaxDays days old)" -Level Success
            return $false
        }
    } catch {
        Write-SetupLog "Error checking age: $_ - download required" -Level Warning
        return $true
    }
}

function Set-SysinternalsAge {
    <#
    .SYNOPSIS
        Updates the age check file with current date
    #>
    [CmdletBinding()]
    param(
        [string]$AgeFile = $AgeCheckFile
    )
    
    try {
        $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $currentDate | Out-File -FilePath $AgeFile -Force
        Write-SetupLog "Updated age check file with current date" -Level Debug
    } catch {
        Write-SetupLog "Error updating age check file: $_" -Level Warning
    }
}
#endregion

#region Main Script
try {
    Write-SetupLog "Starting Sysinternals Suite check..." -Level Info
    Write-SetupLog ("=" * 60) -Level Info
    
    # Check if update is needed
    if (-not (Test-SysinternalsAge)) {
        Write-SetupLog "Sysinternals tools are current - skipping download" -Level Success
        
        # Verify key tools still exist
        $keyTools = @("ProcExp.exe", "ProcMon.exe", "PsExec.exe", "Handle.exe")
        $allToolsExist = $true
        
        foreach ($tool in $keyTools) {
            if (-not (Test-Path (Join-Path $SysinternalsPath $tool))) {
                Write-SetupLog "Key tool missing: $tool" -Level Warning
                $allToolsExist = $false
                break
            }
        }
        
        if ($allToolsExist) {
            Write-SetupLog "All key tools verified - no update needed" -Level Success
            Write-SetupLog ("=" * 60) -Level Info
            exit 0
        } else {
            Write-SetupLog "Some tools missing - proceeding with download" -Level Info
        }
    }
    
    # Create Sysinternals directory
    Write-SetupLog "Creating directory: $SysinternalsPath" -Level Debug
    if (-not (Test-Path $SysinternalsPath)) {
        New-Item -ItemType Directory -Path $SysinternalsPath -Force | Out-Null
        Write-SetupLog "Directory created successfully" -Level Success
    } else {
        Write-SetupLog "Directory already exists" -Level Debug
    }
    
    # Download Sysinternals Suite
    Write-SetupLog "Downloading from: $SysinternalsUrl" -Level Info
    Write-SetupLog "This may take a minute..." -Level Info
    
    $zipPath = Join-Path $env:TEMP "SysinternalsSuite.zip"
    
    # Use Start-BitsTransfer if available, otherwise fall back to WebClient
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $SysinternalsUrl -Destination $zipPath -ErrorAction Stop
    } else {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($SysinternalsUrl, $zipPath)
    }
    
    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-SetupLog "Download completed - Size: $([math]::Round($zipSize, 2)) MB" -Level Success
    
    # Extract files
    Write-SetupLog "Extracting Sysinternals tools..." -Level Info
    
    # Use Expand-Archive if available (PowerShell 5.0+)
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $zipPath -DestinationPath $SysinternalsPath -Force
    } else {
        # Fallback to Shell.Application COM object
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($zipPath)
        $destination = $shell.NameSpace($SysinternalsPath)
        $destination.CopyHere($zip.Items(), 0x14)
    }
    
    # Verify extraction
    $extractedFiles = Get-ChildItem -Path $SysinternalsPath -File
    Write-SetupLog "Extracted $($extractedFiles.Count) files" -Level Success
    
    # Update age check file
    Set-SysinternalsAge
    
    # Add to PATH
    Write-SetupLog "Checking system PATH..." -Level Debug
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -notlike "*$SysinternalsPath*") {
        Write-SetupLog "Adding Sysinternals to system PATH..." -Level Info
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$SysinternalsPath", "Machine")
        
        # Update current session
        $env:Path = "$env:Path;$SysinternalsPath"
        Write-SetupLog "Sysinternals added to system PATH" -Level Success
        Write-SetupLog "Current session PATH updated" -Level Success
    } else {
        Write-SetupLog "Sysinternals already in PATH" -Level Debug
    }
    
    # Clean up
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Write-SetupLog "Cleaned up temporary files" -Level Debug
    
    # Display summary
    Write-SetupLog ("=" * 60) -Level Info
    Write-SetupLog "Sysinternals Suite installation completed!" -Level Success
    Write-SetupLog "" -Level Info
    Write-SetupLog "Installation location: $SysinternalsPath" -Level Info
    Write-SetupLog "Available on Public Desktop for all users" -Level Info
    Write-SetupLog "Total tools installed: $($extractedFiles.Count)" -Level Info
    Write-SetupLog "" -Level Info
    Write-SetupLog "You can now run Sysinternals tools from any command prompt!" -Level Success
    Write-SetupLog "Example: procexp, procmon, psexec, handle, autoruns" -Level Info
    Write-SetupLog "" -Level Info
    Write-SetupLog "All users can access the tools from their Desktop" -Level Info
    
} catch {
    Write-SetupLog "Error during Sysinternals installation: $_" -Level Error
    Write-SetupLog $_.ScriptStackTrace -Level Error
    exit 1
}
#endregion