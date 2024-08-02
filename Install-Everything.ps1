# Install-Everything.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-everything.log')
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
            $bitsTransferParams = @{
                Source      = $Source
                Destination = $Destination
                ErrorAction = "Stop"
            }
            Start-BitsTransfer @bitsTransferParams
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

function Get-LatestEverythingUrl {
    try {
        Write-Log "Fetching the latest Everything release info..."
        $html = Invoke-WebRequest -Uri 'https://www.voidtools.com/downloads/' -Headers @{ 'User-Agent' = 'PowerShell' }
        $downloadUrl = ($html.Links | Where-Object { $_.href -match 'Everything.*x64.*Setup\.exe$' } | Select-Object -First 1 -ExpandProperty href).TrimStart("/")
        if (-not $downloadUrl) {
            throw "Could not find the download URL for the latest Everything version."
        }

        # Ensure the URL includes the protocol
        $downloadUrl = "https://www.voidtools.com/$downloadUrl"

        Write-Log "Latest Everything URL found: $downloadUrl"
        return $downloadUrl
    } catch {
        Write-Log "Error fetching the latest Everything release info: $_" -Level "ERROR"
        exit 1
    }
}

function Install-Everything {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Everything.exe')

    try {
        $url = Get-LatestEverythingUrl
        Write-Log "Downloading Everything from $url..."
        $bitsTransferParams = @{
            Source      = $url
            Destination = $installerPath
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log 'Download complete.'
    } catch {
        Write-Log "Error downloading Everything: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Write-Log "Installer path: $installerPath"

    try {
        Write-Log 'Installing Everything...'
        $startProcessParams = @{
            FilePath     = $installerPath
            ArgumentList = '/S'
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log 'Installation complete.'
    } catch {
        Write-Log "Error installing Everything: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Everything function
Install-Everything
