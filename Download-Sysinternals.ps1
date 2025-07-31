#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Downloads and extracts the Sysinternals Suite to Public Desktop
.DESCRIPTION
    This script downloads the complete Sysinternals Suite from Microsoft,
    extracts it to the Public Desktop (C:\Users\Public\Desktop\Sysinternals),
    making it available for all users, and adds the directory to the system PATH
.EXAMPLE
    .\Download-Sysinternals.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$SysinternalsPath = Join-Path $PublicDesktop "Sysinternals"
$SysinternalsUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
#endregion

#region Functions
function Write-SysinternalsLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}
#endregion

#region Main Script
try {
    Write-SysinternalsLog "Starting Sysinternals Suite download and installation..." -Level Success
    Write-SysinternalsLog ("=" * 60)
    
    # Create Sysinternals directory
    Write-SysinternalsLog "Creating directory: $SysinternalsPath" -Level Info
    if (-not (Test-Path $SysinternalsPath)) {
        New-Item -ItemType Directory -Path $SysinternalsPath -Force | Out-Null
        Write-SysinternalsLog "Directory created successfully" -Level Success
    }
    else {
        Write-SysinternalsLog "Directory already exists" -Level Info
    }
    
    # Download Sysinternals Suite
    $zipPath = Join-Path $env:TEMP "SysinternalsSuite.zip"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        
        Write-SysinternalsLog "Downloading from: $SysinternalsUrl" -Level Info
        Write-SysinternalsLog "This may take a minute..." -Level Info
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri $SysinternalsUrl -OutFile $zipPath -UseBasicParsing
        $stopwatch.Stop()
        
        $downloadTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Write-SysinternalsLog "Download completed in $downloadTime seconds" -Level Success
        
        # Extract to Sysinternals directory
        Write-SysinternalsLog "Extracting Sysinternals tools..." -Level Info
        
        # Clear existing files if any
        if ((Get-ChildItem $SysinternalsPath -ErrorAction SilentlyContinue).Count -gt 0) {
            Write-SysinternalsLog "Clearing existing files..." -Level Info
            Remove-Item "$SysinternalsPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Expand-Archive -Path $zipPath -DestinationPath $SysinternalsPath -Force
        
        # Verify some key tools exist
        $keyTools = @(
            @{Name = "ProcExp.exe"; Description = "Process Explorer"},
            @{Name = "ProcMon.exe"; Description = "Process Monitor"},
            @{Name = "PsExec.exe"; Description = "PsExec"},
            @{Name = "Handle.exe"; Description = "Handle"},
            @{Name = "autoruns.exe"; Description = "Autoruns"},
            @{Name = "TCPView.exe"; Description = "TCPView"}
        )
        
        Write-SysinternalsLog "`nVerifying key tools:" -Level Info
        $foundTools = 0
        
        foreach ($tool in $keyTools) {
            $toolPath = Join-Path $SysinternalsPath $tool.Name
            if (Test-Path $toolPath) {
                Write-SysinternalsLog "  ✓ $($tool.Description) ($($tool.Name))" -Level Success
                $foundTools++
            }
            else {
                Write-SysinternalsLog "  ✗ $($tool.Description) ($($tool.Name))" -Level Warning
            }
        }
        
        if ($foundTools -eq $keyTools.Count) {
            Write-SysinternalsLog "`nAll key tools verified successfully!" -Level Success
        }
        elseif ($foundTools -gt 0) {
            Write-SysinternalsLog "`n$foundTools of $($keyTools.Count) key tools verified" -Level Warning
        }
        else {
            throw "No key tools found - extraction may have failed"
        }
        
        # Add to PATH if not already there
        Write-SysinternalsLog "`nChecking system PATH..." -Level Info
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        if ($currentPath -notlike "*$SysinternalsPath*") {
            Write-SysinternalsLog "Adding Sysinternals to system PATH..." -Level Info
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$SysinternalsPath", "Machine")
            Write-SysinternalsLog "Sysinternals added to system PATH" -Level Success
            
            # Update current session PATH
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:Path = "$machinePath;$userPath"
            Write-SysinternalsLog "Current session PATH updated" -Level Success
        }
        else {
            Write-SysinternalsLog "Sysinternals already in system PATH" -Level Info
        }
        
        # Clean up zip file
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Write-SysinternalsLog "Cleaned up temporary files" -Level Info
        
        # Show summary
        Write-SysinternalsLog ("=" * 60)
        Write-SysinternalsLog "Sysinternals Suite installation completed!" -Level Success
        Write-SysinternalsLog "`nInstallation location: $SysinternalsPath" -Level Info
        Write-SysinternalsLog "Available on Public Desktop for all users" -Level Success
        
        $toolCount = (Get-ChildItem $SysinternalsPath -Filter "*.exe" -ErrorAction SilentlyContinue).Count
        Write-SysinternalsLog "Total tools installed: $toolCount" -Level Info
        
        Write-SysinternalsLog "`nYou can now run Sysinternals tools from any command prompt!" -Level Success
        Write-SysinternalsLog "Example: procexp, procmon, psexec, handle, autoruns" -Level Info
        Write-SysinternalsLog "`nAll users can access the tools from their Desktop" -Level Info
    }
    catch {
        Write-SysinternalsLog "Failed to download/extract Sysinternals: $_" -Level Error
        
        # Clean up on failure
        if (Test-Path $zipPath) {
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        }
        
        exit 1
    }
}
catch {
    Write-SysinternalsLog "Error occurred: $($_.Exception.Message)" -Level Error
    Write-SysinternalsLog $_.Exception.Message -Level Error
    exit 1
}
#endregion