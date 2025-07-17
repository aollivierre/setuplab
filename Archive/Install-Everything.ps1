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
            if (-not (Test-Path -Path (Split-Path $Destination -Parent))) {
                throw "Destination path does not exist: $(Split-Path $Destination -Parent)"
            }
            Start-BitsTransfer -Source $Source -Destination $Destination -ErrorAction Stop
            $success = $true
        }
        catch {
            Write-Log "Attempt $attempt failed: $_" -Level "ERROR"
            if ($attempt -eq $MaxRetries) {
                throw "Maximum retry attempts reached. Download failed."
            }
            Start-Sleep -Seconds 5
        }
    }
}

# Function to get the latest download URL for Everything
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
    }
    catch {
        Write-Log "Error fetching the latest Everything release info: $_" -Level "ERROR"
        exit 1
    }
}

# Function to validate Everything installation via registry
function Validate-EverythingInstallation {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $softwareName = "*Everything*"
    $minVersion = New-Object Version "1.4.1.1026"  # Adjust this version as needed

    foreach ($path in $registryPaths) {
        if (-not (Test-Path $path)) {
            Write-Log "Registry path not found: $path" -Level "ERROR"
            continue
        }

        $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like $softwareName) {
                $installedVersion = New-Object Version $app.DisplayVersion
                if ($installedVersion -ge $minVersion) {
                    return @{
                        IsInstalled = $true
                        Version     = $installedVersion
                        ProductCode = $app.PSChildName
                    }
                }
            }
        }
    }

    return @{IsInstalled = $false }
}


# Main function to install Everything
function Install-Everything {
    $totalSteps = 5  # Updated to reflect the correct number of steps
    $completedSteps = 0

    # Step 1: Pre-installation validation
    Write-Log "Step 1: Validating existing installation of Everything..."
    $preInstallCheck = Validate-EverythingInstallation
    if ($preInstallCheck.IsInstalled) {
        Write-Log "Everything version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "Everything is not currently installed." -Level "INFO"
    }
    $completedSteps++

    # Step 2: Fetching the latest Everything release info
    Write-Log "Step 2: Fetching the latest Everything release info..."
    try {
        $url = Get-LatestEverythingUrl
    }
    catch {
        Write-Log "Error fetching release info: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 3: Downloading Everything installer
    Write-Log "Step 3: Downloading Everything installer from $url..."
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Everything.exe')
    try {
        Start-BitsTransferWithRetry -Source $url -Destination $installerPath
        Write-Log "Downloaded Everything installer to $installerPath"
    }
    catch {
        Write-Log "Error downloading Everything installer: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 4: Installing Everything
    Write-Log "Step 4: Installing Everything..."
    try {
        $startProcessParams = @{
            FilePath     = $installerPath
            ArgumentList = '/S'
            Wait         = $true
        }
        Start-Process @startProcessParams | Wait-Process
        Write-Log "Everything installation complete."
    }
    catch {
        Write-Log "Error installing Everything: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 5: Post-installation validation with retry mechanism
    Write-Log "Step 5: Validating Everything installation..."
    $maxRetries = 3
    $retryCount = 0
    $delayBetweenRetries = 5  # Delay in seconds

    $validationSucceeded = $false
    while ($retryCount -lt $maxRetries -and -not $validationSucceeded) {
        Start-Sleep -Seconds $delayBetweenRetries  # Wait before checking
        $postInstallCheck = Validate-EverythingInstallation
        if ($postInstallCheck.IsInstalled) {
            Write-Log "Validation successful: Everything version $($postInstallCheck.Version) is installed."
            $validationSucceeded = $true
            $completedSteps++
        }
        else {
            Write-Log "Validation attempt $($retryCount + 1) failed: Everything was not found on the system." -Level "ERROR"
        }
        $retryCount++
    }

    if (-not $validationSucceeded) {
        Write-Log "Validation failed after $maxRetries attempts: Everything was not found on the system." -Level "ERROR"
    }

    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "Everything was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }
}

# Call the Install-Everything function
Install-Everything