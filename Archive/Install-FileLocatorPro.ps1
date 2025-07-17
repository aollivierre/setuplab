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

# Function to validate the installation of File Locator Pro
function Validate-FileLocatorProInstallation {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $softwareName = "*FileLocator Pro*"
    $minVersion = New-Object Version "9.2.3435.1"

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

function Get-LatestFileLocatorProUrl {
    try {
        Write-Log 'Fetching latest File Locator Pro URL...'
        $html = Invoke-WebRequest -Uri 'https://www.mythicsoft.com/filelocatorpro/download/'
        $url = $html.Links | Where-Object { $_.href -like '*filelocator_x64_msi_*.zip' } | Select-Object -First 1 -ExpandProperty href
        if (-not $url) {
            throw "Could not find the download URL for the latest File Locator Pro."
        }

        if ($url -notmatch '^https?://') {
            $url = "https:$url"
        }

        Write-Log "Latest File Locator Pro URL found: $url"
        return $url
    }
    catch {
        Write-Log "Error fetching latest File Locator Pro URL: $_" -Level "ERROR"
        exit 1
    }
}

function Install-FileLocatorPro {
    $downloadUrl = Get-LatestFileLocatorProUrl
    $zipPath = [System.IO.Path]::Combine($env:TEMP, 'filelocator_x64_msi.zip')
    $extractPath = [System.IO.Path]::Combine($env:TEMP, 'FileLocatorPro')

    # Ensure paths are valid before proceeding
    try {
        if (-not (Test-Path -Path (Split-Path $zipPath -Parent))) {
            throw "Temporary directory does not exist: $(Split-Path $zipPath -Parent)"
        }

        if (-not (Test-Path -Path (Split-Path $extractPath -Parent))) {
            throw "Extraction directory does not exist: $(Split-Path $extractPath -Parent)"
        }
    }
    catch {
        Write-Log "Error with file paths: $_" -Level "ERROR"
        exit 1
    }

    # Pre-installation validation
    Write-Log "Validating existing installation of File Locator Pro..."
    $preInstallCheck = Validate-FileLocatorProInstallation
    if ($preInstallCheck.IsInstalled) {
        Write-Log "File Locator Pro version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "File Locator Pro is not currently installed." -Level "INFO"
    }

    try {
        Write-Log 'Downloading File Locator Pro...'
        Start-BitsTransferWithRetry -Source $downloadUrl -Destination $zipPath
        Write-Log 'Download complete.'
    }
    catch {
        Write-Log "Error downloading File Locator Pro: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log 'Extracting File Locator Pro...'
        if (-not (Test-Path $zipPath)) {
            throw "Zip file not found: $zipPath"
        }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Log 'Extraction complete.'
    
        # Set the MSI path dynamically after extraction
        $msiPath = Get-ChildItem -Path $extractPath -Filter 'filelocator_x64_*.msi' | Select-Object -First 1 | ForEach-Object { $_.FullName }
        if (-not $msiPath) {
            throw "MSI file not found after extraction."
        }
    }
    catch {
        Write-Log "Error extracting File Locator Pro: $_" -Level "ERROR"
        exit 1
    }
    

    try {
        Write-Log "Installer path: $msiPath"
        if (-not (Test-Path $msiPath)) {
            throw "MSI file not found: $msiPath"
        }

        Write-Log 'Installing File Locator Pro...'
        $startProcessParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = @("/i", "`"$msiPath`"", "/quiet", "/norestart")
            Wait         = $true
        }
        Start-Process @startProcessParams | Wait-Process
        Write-Log 'Installation complete.'
    }
    catch {
        Write-Log "Error installing File Locator Pro: $_" -Level "ERROR"
        exit 1
    }

    # Post-installation validation
    Write-Log "Validating post-installation of File Locator Pro..."
    $postInstallCheck = Validate-FileLocatorProInstallation
    if ($postInstallCheck.IsInstalled) {
        Write-Log "Validation successful: File Locator Pro version $($postInstallCheck.Version) is installed." -Level "INFO"
    }
    else {
        Write-Log "Validation failed: File Locator Pro was not found on the system after installation." -Level "ERROR"
    }

    try {
        Write-Log 'Cleaning up temporary files...'
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Recurse -Force
        }
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        Write-Log 'Cleanup complete.'
    }
    catch {
        Write-Log "Error during cleanup: $_" -Level "ERROR"
        exit 1
    }

    # Summary report
    $totalSteps = 3
    $completedSteps = 0

    if ($preInstallCheck.IsInstalled -eq $false) {
        Write-Log "Step 1: Pre-installation check - No previous installation found" -Level "INFO"
        $completedSteps++
    }

    if ($postInstallCheck.IsInstalled) {
        Write-Log "Step 2: Installation - Successful" -Level "INFO"
        $completedSteps++
    }
    else {
        Write-Log "Step 2: Installation - Failed" -Level "ERROR"
    }

    if (-not (Test-Path $extractPath) -and -not (Test-Path $zipPath)) {
        Write-Log "Step 3: Cleanup - Successful" -Level "INFO"
        $completedSteps++
    }
    else {
        Write-Log "Step 3: Cleanup - Failed" -Level "ERROR"
        $completedSteps--  # Ensure failed cleanup doesn't count towards success
    }
    

    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "File Locator Pro was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }

    Read-Host 'Press Enter to close this window...'
}


# Call the Install-FileLocatorPro function
Install-FileLocatorPro