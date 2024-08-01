# Install-Git.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-git.log')
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

function Get-LatestGitUrl {
    try {
        Write-Log 'Fetching latest Git version URL...'
        $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
        }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        $installerUrl = $response.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -ExpandProperty browser_download_url
        if (-not $installerUrl) {
            throw "Could not find the download URL for the latest Git version."
        }
        Write-Log "Latest Git version URL found: $installerUrl"
        return $installerUrl
    } catch {
        Write-Log "Error fetching latest Git version URL: $_" -Level "ERROR"
        exit 1
    }
}

function Install-Git {
    $downloadUrl = Get-LatestGitUrl
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Git-Installer.exe')

    try {
        Write-Log 'Downloading Git...'
        $bitsTransferParams = @{
            Source      = $downloadUrl
            Destination = $installerPath
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log 'Download complete.'
    } catch {
        Write-Log "Error downloading Git: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Write-Log "Installer path: $installerPath"

    try {
        Write-Log 'Installing Git...'
        $startProcessParams = @{
            FilePath     = $installerPath
            ArgumentList = '/SILENT'
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log 'Installation complete.'
    } catch {
        Write-Log "Error installing Git: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Git function
Install-Git
