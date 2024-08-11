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

# Function to validate 7-Zip installation via registry
function Validate-7ZipInstallation {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $softwareName = "*7-Zip*"
    $minVersion = New-Object Version "24.07.0.0"  # Adjust this version as needed

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

# Main function to install 7-Zip
function Install-7Zip {
    $totalSteps = 6  # Updated to reflect the correct number of steps
    $completedSteps = 0

    # Step 1: Pre-installation validation
    Write-Log "Step 1: Validating existing installation of 7-Zip..."
    $preInstallCheck = Validate-7ZipInstallation
    if ($preInstallCheck.IsInstalled) {
        Write-Log "7-Zip version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "7-Zip is not currently installed." -Level "INFO"
    }
    $completedSteps++

    # Step 2: Fetching the latest 7-Zip release info
    Write-Log "Step 2: Fetching the latest 7-Zip release info..."
    try {
        $releaseUrl = 'https://api.github.com/repos/ip7z/7zip/releases/latest'
        $releaseInfo = Invoke-RestMethod -Uri $releaseUrl
    }
    catch {
        Write-Log "Error fetching release info: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 3: Finding the MSI asset URL
    Write-Log "Step 3: Finding the MSI asset URL..."
    try {
        $msiAssets = $releaseInfo.assets | Where-Object { $_.name -like '*.msi' }
        if (-not $msiAssets) {
            throw "7-Zip MSI installer not found in the latest release."
        }
        $msiAsset = $msiAssets | Where-Object { $_.name -like '*x64.msi' } | Select-Object -First 1
        if (-not $msiAsset) {
            $msiAsset = $msiAssets | Select-Object -First 1
        }
        $msiUrl = $msiAsset.browser_download_url
        Write-Log "Found MSI asset URL: $msiUrl"
    }
    catch {
        Write-Log "Error finding MSI asset: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 4: Downloading the MSI file
    Write-Log "Step 4: Downloading the MSI file..."
    $msiPath = "$env:TEMP\7z_latest.msi"
    try {
        Start-BitsTransferWithRetry -Source $msiUrl -Destination $msiPath
        Write-Log "Downloaded MSI file to $msiPath"
    }
    catch {
        Write-Log "Error downloading MSI file: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 5: Installing 7-Zip
    Write-Log "Step 5: Installing 7-Zip..."
    try {
        $startProcessParams = @{
            FilePath     = "msiexec.exe"
            ArgumentList = @("/i", "`"$msiPath`"", "/quiet", "/norestart")
            Wait         = $true
        }
        Start-Process @startProcessParams | Wait-Process
        Write-Log "7-Zip installation complete."
    }
    catch {
        Write-Log "Error installing 7-Zip: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 6: Post-installation validation
    Write-Log "Step 6: Validating 7-Zip installation..."
    $postInstallCheck = Validate-7ZipInstallation
    if ($postInstallCheck.IsInstalled) {
        Write-Log "Validation successful: 7-Zip version $($postInstallCheck.Version) is installed."
        $completedSteps++
    }
    else {
        Write-Log "Validation failed: 7-Zip was not found on the system." -Level "ERROR"
        $completedSteps--
    }

    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "7-Zip was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }
}

# Call the Install-7Zip function
Install-7Zip
