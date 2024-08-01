# Install-PowerShell7.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-powershell7.log')
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

function Install-PowerShell7 {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    try {
        Write-Log "Fetching the latest PowerShell release info..."
        $restMethodParams = @{
            Uri     = 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
            Headers = @{ 'User-Agent' = 'PowerShell' }
        }
        $latestRelease = Invoke-RestMethod @restMethodParams
        $url = $latestRelease.assets | Where-Object { $_.name -like '*win-x64.msi' } | Select-Object -ExpandProperty browser_download_url
        Write-Log "Latest PowerShell MSI URL found: $url"
    } catch {
        Write-Log "Error fetching the latest PowerShell release info: $_" -Level "ERROR"
        exit 1
    }

    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'pwsh.msi')

    try {
        Write-Log "Downloading PowerShell from $url..."
        $bitsTransferParams = @{
            Source      = $url
            Destination = $installerPath
            Description = "Downloading PowerShell MSI"
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log "Download complete."
    } catch {
        Write-Log "Error downloading PowerShell: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    try {
        Write-Log "Installing PowerShell..."
        $msiParams = "/i $installerPath /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"
        $startProcessParams = @{
            FilePath     = 'msiexec.exe'
            ArgumentList = $msiParams
            Wait         = $true
            PassThru     = $true
        }
        $installProcess = Start-Process @startProcessParams

        if ($installProcess.ExitCode -eq 0) {
            Write-Log "PowerShell installation completed successfully."
        } else {
            Write-Log "PowerShell installation failed. Exit code: $($installProcess.ExitCode)" -Level "ERROR"
        }
    } catch {
        Write-Log "Error installing PowerShell: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-PowerShell7 function
Install-PowerShell7
