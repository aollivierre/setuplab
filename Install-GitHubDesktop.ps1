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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-githubdesktop.log')
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
            $bitsTransferParams = @{
                Source      = $Source
                Destination = $Destination
                ErrorAction = "Stop"
            }
            Start-BitsTransfer @bitsTransferParams
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


# Function to validate the installation of GitHub Desktop
function Validate-GitHubDesktopInstallation {
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubDesktop"
    $minVersion = New-Object Version "3.4.3"  # Adjust this version as needed

    if (Test-Path $registryPath) {
        $app = Get-ItemProperty -Path $registryPath
        $installedVersion = New-Object Version $app.DisplayVersion
        if ($installedVersion -ge $minVersion) {
            return @{
                IsInstalled = $true
                Version     = $installedVersion
                ProductCode = $app.PSChildName
            }
        }
    }

    return @{IsInstalled = $false }
}



function Install-GitHubDesktop {
    $totalSteps = 6
    $completedSteps = 0
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'GitHubDesktop.exe')
    $downloadUrl = 'https://central.github.com/deployments/desktop/desktop/latest/win32'

    # Step 1: Pre-installation validation
    Write-Log "Step 1: Validating existing installation of GitHub Desktop..."
    $preInstallCheck = Validate-GitHubDesktopInstallation
    if ($preInstallCheck.IsInstalled) {
        Write-Log "GitHub Desktop version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "GitHub Desktop is not currently installed." -Level "INFO"
    }
    $completedSteps++

    # Step 2: Downloading GitHub Desktop
    Write-Log "Step 2: Downloading GitHub Desktop from $downloadUrl..."
    try {
        Start-BitsTransferWithRetry -Source $downloadUrl -Destination $installerPath
        Write-Log 'Download complete.'
    }
    catch {
        Write-Log "Error downloading GitHub Desktop: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    Write-Log "Installer path: $installerPath"

 
    # Step 3: Installing GitHub Desktop
    Write-Log "Step 3: Installing GitHub Desktop..."
    try {
        $process = Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait -PassThru
        if ($process) {
            $process.WaitForExit()  # Ensure the process has fully completed
            Write-Log 'Installation complete.'
        }
        else {
            throw "Failed to start the installation process."
        }
    }
    catch {
        Write-Log "Error installing GitHub Desktop: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++


    # Step 4: Post-installation validation
    Write-Log "Step 4: Validating GitHub Desktop installation..."
    $maxRetries = 3
    $retryCount = 0
    $delayBetweenRetries = 5  # Delay in seconds

    $validationSucceeded = $false
    while ($retryCount -lt $maxRetries -and -not $validationSucceeded) {
        Start-Sleep -Seconds $delayBetweenRetries  # Wait before checking
        $postInstallCheck = Validate-GitHubDesktopInstallation
        if ($postInstallCheck.IsInstalled) {
            Write-Log "Validation successful: GitHub Desktop version $($postInstallCheck.Version) is installed."
            $validationSucceeded = $true
            $completedSteps++
        }
        else {
            Write-Log "Validation attempt $($retryCount + 1) failed: GitHub Desktop was not found on the system." -Level "ERROR"
        }
        $retryCount++
    }

    if (-not $validationSucceeded) {
        Write-Log "Validation failed after $maxRetries attempts: GitHub Desktop was not found on the system." -Level "ERROR"
    }


    # Step 5: Cleaning up temporary files...
    Write-Log "Step 5: Cleaning up temporary files..."
    try {
        Start-Sleep -Seconds 5  # Small delay to ensure file handles are released
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
        Write-Log 'Cleanup complete.'
    }
    catch {
        Write-Log "Error during cleanup: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++


    # Adjust the completed steps calculation
    if ($validationSucceeded) {
        $completedSteps++  # Only increment if validation ultimately succeeds
    }

    # Summary report
    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "GitHub Desktop was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }


    Read-Host 'Press Enter to close this window...'
}

# Call the Install-GitHubDesktop function
Install-GitHubDesktop