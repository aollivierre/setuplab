# Install-FileLocatorPro.ps1

# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function for logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-FilelocatorPro.log')
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

# Elevate to administrator if not already
if (-not (Test-Admin)) {
    Write-Log "Restarting script with elevated permissions..."
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
        Verb         = "RunAs"
    }
    Start-Process @startProcessParams
    exit
}

function Start-BitsTransferWithRetry {
    param (
        [string]$Source,
        [string]$Destination,
        [int]$MaxRetries = 3
    )
    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        try {
            $attempt++
            Start-BitsTransfer -Source $Source -Destination $Destination -ErrorAction Stop
            $success = $true
        } catch {
            Write-Log "Attempt $attempt failed: $_" -Level "ERROR"
            if ($attempt -eq $MaxRetries) {
                throw "Maximum retry attempts reached."
            }
            Start-Sleep -Seconds 5
        }
    }
}

function Get-LatestFileLocatorProUrl {
    try {
        Write-Log 'Fetching latest File Locator Pro URL...'
        $html = Invoke-WebRequest -Uri 'https://www.mythicsoft.com/filelocatorpro/download/'
        $url = $html.Links | Where-Object { $_.href -like '*filelocator_x64_msi_*.zip' } | Select-Object -First 1 -ExpandProperty href
        if (-not $url) {
            throw "Could not find the download URL for the latest File Locator Pro."
        }

        # Ensure the URL includes the protocol
        if ($url -notmatch '^https?://') {
            $url = "https:$url"
        }

        Write-Log "Latest File Locator Pro URL found: $url"
        return $url
    } catch {
        Write-Log "Error fetching latest File Locator Pro URL: $_" -Level "ERROR"
        exit 1
    }
}

function Install-FileLocatorPro {
    $downloadUrl = Get-LatestFileLocatorProUrl
    $zipPath = [System.IO.Path]::Combine($env:TEMP, 'filelocator_x64_msi.zip')
    $extractPath = [System.IO.Path]::Combine($env:TEMP, 'FileLocatorPro')
    $msiPath = [System.IO.Path]::Combine($extractPath, 'filelocator_x64.msi')

    try {
        Write-Log 'Downloading File Locator Pro...'
        Start-BitsTransferWithRetry -Source $downloadUrl -Destination $zipPath
        Write-Log 'Download complete.'
    } catch {
        Write-Log "Error downloading File Locator Pro: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log 'Extracting File Locator Pro...'
        $expandArchiveParams = @{
            Path             = $zipPath
            DestinationPath  = $extractPath
            Force            = $true
        }
        Expand-Archive @expandArchiveParams
        Write-Log 'Extraction complete.'
    } catch {
        Write-Log "Error extracting File Locator Pro: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log "Installer path: $msiPath"
        Write-Log 'Installing File Locator Pro...'
        $startProcessParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = @("/i", $msiPath, "/quiet", "/norestart")
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log 'Installation complete.'
    } catch {
        Write-Log "Error installing File Locator Pro: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log 'Cleaning up temporary files...'
        $removeItemParams = @{
            Path    = @($zipPath, $extractPath)
            Recurse = $true
            Force   = $true
        }
        Remove-Item @removeItemParams
        Write-Log 'Cleanup complete.'
    } catch {
        Write-Log "Error during cleanup: $_" -Level "ERROR"
        exit 1
    }
    
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-FileLocatorPro function
Install-FileLocatorPro
