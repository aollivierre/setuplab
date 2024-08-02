# Install-VSCode.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-vscode.log')
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

function Install-VSCode {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'VSCode.exe')

    try {
        Write-Log 'Downloading VS Code...'
        $bitsTransferParams = @{
            Source      = 'https://update.code.visualstudio.com/latest/win32-x64/stable'
            Destination = $installerPath
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log 'Download complete.'
    } catch {
        Write-Log "Error downloading VS Code: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Write-Log "Installer path: $installerPath"

    try {
        Write-Log 'Installing VS Code...'
        $startProcessParams = @{
            FilePath     = $installerPath
            ArgumentList = '/silent /mergetasks=!runcode'
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log 'Installation complete.'
    } catch {
        Write-Log "Error installing VS Code: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-VSCode function
Install-VSCode
