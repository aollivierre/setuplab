# Install-WindowsTerminal.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-windowsterminal.log')
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

function Get-LatestWindowsTerminalUrl {
    try {
        Write-Log "Fetching the latest Windows Terminal release info..."
        $restMethodParams = @{
            Uri     = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
            Headers = @{ 'User-Agent' = 'PowerShell' }
        }
        $latestRelease = Invoke-RestMethod @restMethodParams
        $url = $latestRelease.assets | Where-Object { $_.name -like '*x64.zip' } | Select-Object -ExpandProperty browser_download_url
        Write-Log "Latest Windows Terminal ZIP URL found: $url"
        return $url
    } catch {
        Write-Log "Error fetching the latest Windows Terminal release info: $_" -Level "ERROR"
        exit 1
    }
}

function Install-WindowsTerminal {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $url = Get-LatestWindowsTerminalUrl

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $zipPath = [System.IO.Path]::Combine($env:TEMP, "WindowsTerminal_$timestamp.zip")
    $extractPath = [System.IO.Path]::Combine($env:TEMP, "WindowsTerminal_$timestamp")

    try {
        Write-Log "Downloading Windows Terminal from $url..."
        $bitsTransferParams = @{
            Source      = $url
            Destination = $zipPath
            Description = "Downloading Windows Terminal ZIP"
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log "Download complete."
    } catch {
        Write-Log "Error downloading Windows Terminal: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    try {
        Write-Log "Extracting Windows Terminal..."
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $extractPath -ItemType Directory | Out-Null
        $expandArchiveParams = @{
            Path           = $zipPath
            DestinationPath = $extractPath
            Force          = $true
        }
        Expand-Archive @expandArchiveParams
        Write-Log "Extraction complete."
    } catch {
        Write-Log "Error extracting Windows Terminal: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    try {
        Write-Log "Creating shortcut for Windows Terminal..."
        $exePath = Get-ChildItem -Path $extractPath -Filter "WindowsTerminal.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = [System.IO.Path]::Combine($desktopPath, 'Windows Terminal.lnk')
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.Save()
        Write-Log 'Shortcut created on the desktop.'
    } catch {
        Write-Log "Error creating shortcut: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Write-Log "Installation complete."
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-WindowsTerminal function
Install-WindowsTerminal
