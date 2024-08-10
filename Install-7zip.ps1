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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-7zip.log')
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

# Function to download files with retry logic
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

# Function to validate 7-Zip installation via registry
function Validate-7ZipInstallation {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $softwareName = "*7-Zip*"
    $minVersion = New-Object Version "24.07.0.0"  # Adjust this version as needed

    foreach ($path in $registryPaths) {
        $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue

        foreach ($item in $items) {
            $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like $softwareName) {
                $installedVersion = New-Object Version $app.DisplayVersion
                if ($installedVersion -ge $minVersion) {
                    return @{
                        IsInstalled = $true
                        Version = $app.DisplayVersion
                        ProductCode = $app.PSChildName
                    }
                }
            }
        }
    }

    return @{IsInstalled = $false}
}

# Main function to install 7-Zip
function Install-7Zip {
    # Step 1: Fetching the latest 7-Zip release info
    Write-Log "Fetching the latest 7-Zip release info..."
    $releaseUrl = 'https://api.github.com/repos/ip7z/7zip/releases/latest'
    $releaseInfo = Invoke-RestMethod -Uri $releaseUrl

    # Step 2: Finding the MSI asset URL
    Write-Log "Finding the MSI asset URL..."
    $msiAssets = $releaseInfo.assets | Where-Object { $_.name -like '*.msi' }
    if (-not $msiAssets) {
        throw "7-Zip MSI installer not found in the latest release."
    }

    # Select the appropriate MSI asset (e.g., prefer x64 over x86)
    $msiAsset = $msiAssets | Where-Object { $_.name -like '*x64.msi' } | Select-Object -First 1
    if (-not $msiAsset) {
        $msiAsset = $msiAssets | Select-Object -First 1
    }

    $msiUrl = $msiAsset.browser_download_url
    Write-Log "Found MSI asset URL: $msiUrl"

    # Step 3: Downloading the MSI file
    Write-Log "Downloading the MSI file..."
    $msiPath = "$env:TEMP\7z_latest.msi"
    try {
        Start-BitsTransferWithRetry -Source $msiUrl -Destination $msiPath
        Write-Log "Downloaded MSI file to $msiPath"
    } catch {
        Write-Log "Error downloading MSI file: $_" -Level "ERROR"
        exit 1
    }

    # Step 4: Installing 7-Zip
    Write-Log "Installing 7-Zip..."
    try {
        $startProcessParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = "/i", "`"$msiPath`"", "/quiet", "/norestart"
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log "7-Zip installation complete."
    } catch {
        Write-Log "Error installing 7-Zip: $_" -Level "ERROR"
        exit 1
    }

    # Step 5: Validate installation
    Write-Log "Validating 7-Zip installation..."
    $installationCheck = Validate-7ZipInstallation
    if ($installationCheck.IsInstalled) {
        Write-Log "Validation successful: 7-Zip version $($installationCheck.Version) is installed."
    } else {
        Write-Log "Validation failed: 7-Zip was not found on the system." -Level "ERROR"
        exit 1
    }
}

# Call the Install-7Zip function
Install-7Zip