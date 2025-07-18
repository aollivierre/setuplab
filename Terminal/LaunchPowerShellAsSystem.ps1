function Write-WindowsPowerShellAsSystemLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $outputMessage = "[$timestamp] [$Level] $Message"
    
    # Output with appropriate color
    switch ($Level) {
        "ERROR" { Write-Host $outputMessage -ForegroundColor Red }
        "WARNING" { Write-Host $outputMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $outputMessage -ForegroundColor Green }
        default { Write-Host $outputMessage }
    }
}

function Get-PsExecTool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ModuleTempPath = (Join-Path -Path $env:TEMP -ChildPath "AsSystem-Module\PsExec"),
        
        [Parameter(Mandatory = $false)]
        [int]$CacheExpirationDays = 30
    )
    
    try {
        # Ensure target path exists
        if (-not (Test-Path -Path $ModuleTempPath)) {
            New-Item -Path $ModuleTempPath -ItemType Directory -Force | Out-Null
            Write-WindowsPowerShellAsSystemLog -Message "Created temp directory $ModuleTempPath" -Level "INFO"
        }
        
        $psExecPath = Join-Path -Path $ModuleTempPath -ChildPath "PsExec64.exe"
        $lastDownloadMarker = Join-Path -Path $ModuleTempPath -ChildPath ".last_download"
        
        $needsDownload = $false
        
        # Check if PsExec already exists
        if (Test-Path -Path $psExecPath) {
            Write-WindowsPowerShellAsSystemLog -Message "PsExec64.exe exists at $psExecPath" -Level "INFO"
            
            # Check if the last download marker exists and when it was created
            if (Test-Path -Path $lastDownloadMarker) {
                $lastDownloadDate = Get-Content -Path $lastDownloadMarker
                $lastDownloadDateTime = [DateTime]::ParseExact($lastDownloadDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                $daysSinceLastDownload = (New-TimeSpan -Start $lastDownloadDateTime -End (Get-Date)).Days
                
                Write-WindowsPowerShellAsSystemLog -Message "Last download was on $lastDownloadDate ($daysSinceLastDownload days ago)" -Level "INFO"
                
                # Check if cache has expired
                if ($daysSinceLastDownload -ge $CacheExpirationDays) {
                    Write-WindowsPowerShellAsSystemLog -Message "Cache has expired ($daysSinceLastDownload days old). Will download fresh copy." -Level "INFO"
                    $needsDownload = $true
                }
            } else {
                # No marker file - create one with today's date
                $today = (Get-Date).ToString("yyyy-MM-dd")
                Set-Content -Path $lastDownloadMarker -Value $today -Force
                Write-WindowsPowerShellAsSystemLog -Message "Created download marker with date $today" -Level "INFO"
            }
        } else {
            # PsExec doesn't exist, need to download
            $needsDownload = $true
        }
        
        # If we don't need to download, return the existing path
        if (-not $needsDownload) {
            return $psExecPath
        }
        
        # Download PsExec
        Write-WindowsPowerShellAsSystemLog -Message "Downloading PsExec64.exe from Microsoft..." -Level "INFO"
        
        # URL for PsExec64.exe
        $psToolsUrl = "https://download.sysinternals.com/files/PSTools.zip"
        $zipFilePath = Join-Path -Path $ModuleTempPath -ChildPath "PSTools.zip"
        
        # Download the PSTools zip file
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # Disable progress bar for faster downloads
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $psToolsUrl -OutFile $zipFilePath -UseBasicParsing
        
        # Extract PsExec64.exe from the zip file
        if (Test-Path -Path $psExecPath) {
            # Remove existing file to avoid extraction errors
            Remove-Item -Path $psExecPath -Force
        }
        
        Expand-Archive -Path $zipFilePath -DestinationPath $ModuleTempPath -Force
        
        # Verify PsExec64.exe was extracted
        if (Test-Path -Path $psExecPath) {
            Write-WindowsPowerShellAsSystemLog -Message "PsExec64.exe downloaded and extracted successfully" -Level "INFO"
            
            # Update the last download marker
            $today = (Get-Date).ToString("yyyy-MM-dd")
            Set-Content -Path $lastDownloadMarker -Value $today -Force
            Write-WindowsPowerShellAsSystemLog -Message "Updated download marker with date $today" -Level "INFO"
            
            # Clean up the zip file
            Remove-Item -Path $zipFilePath -Force
            Write-WindowsPowerShellAsSystemLog -Message "Removed temporary zip file" -Level "INFO"
            
            return $psExecPath
        } 
        else {
            $errorMessage = "Failed to extract PsExec64.exe from the downloaded archive"
            Write-WindowsPowerShellAsSystemLog -Message $errorMessage -Level "ERROR"
            throw $errorMessage
        }
    }
    catch {
        $errorMessage = "Error obtaining PsExec64.exe $($_.Exception.Message)"
        Write-WindowsPowerShellAsSystemLog -Message $errorMessage -Level "ERROR"
        throw $errorMessage
    }
}

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
try {
    # Check for admin privileges
    if (-not (Test-AdminPrivileges)) {
        Write-WindowsPowerShellAsSystemLog -Message "This script requires administrator privileges to run." -Level "ERROR"
        Write-WindowsPowerShellAsSystemLog -Message "Please restart Windows Terminal as administrator." -Level "ERROR"
        exit 1
    }
    
    # Get PsExec path (downloads if necessary)
    $psExecPath = Get-PsExecTool
    $psPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    
    # Create the direct process start info for PsExec
    Write-WindowsPowerShellAsSystemLog -Message "Preparing to launch PowerShell as SYSTEM..." -Level "INFO"
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $psExecPath
    $startInfo.Arguments = "-i -s -d -nobanner -accepteula $psPath"
    $startInfo.UseShellExecute = $true
    $startInfo.WindowStyle = 'Hidden'
    
    # Launch PowerShell as SYSTEM
    Write-WindowsPowerShellAsSystemLog -Message "Launching PowerShell as SYSTEM..." -Level "INFO"
    [System.Diagnostics.Process]::Start($startInfo)
    Write-WindowsPowerShellAsSystemLog -Message "PowerShell launched successfully as SYSTEM" -Level "SUCCESS"
    
    # Add slight delay to ensure process starts properly
    Start-Sleep -Seconds 1
    
    # Exit the current PowerShell process
    Write-WindowsPowerShellAsSystemLog -Message "Closing launcher window..." -Level "INFO"
    exit 0
}
catch {
    Write-WindowsPowerShellAsSystemLog -Message "Failed to launch PowerShell as SYSTEM: $($_.Exception.Message)" -Level "ERROR"
    # Keep window open on error
    Write-WindowsPowerShellAsSystemLog -Message "Press any key to exit..." -Level "ERROR"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit 1
} 