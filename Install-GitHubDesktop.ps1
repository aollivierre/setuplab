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
        ArgumentList = @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
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


# Function to validate the installation of GitHub Desktop with splat parameters
function Validate-GitHubDesktopInstallation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RegistryPath,
        
        [Parameter(Mandatory=$true)]
        [version]$MinVersion,
        
        [Parameter(Mandatory=$true)]
        [int]$MaxRetries,
        
        [Parameter(Mandatory=$true)]
        [int]$DelayBetweenRetries
    )
    
    $retryCount = 0
    $validationSucceeded = $false

    while ($retryCount -lt $MaxRetries -and -not $validationSucceeded) {
        if (Test-Path $RegistryPath) {
            $app = Get-ItemProperty -Path $RegistryPath
            $installedVersion = New-Object Version $app.DisplayVersion
            if ($installedVersion -ge $MinVersion) {
                return @{
                    IsInstalled = $true
                    Version     = $installedVersion
                    ProductCode = $app.PSChildName
                }
            }
        }

        $retryCount++
        if (-not $validationSucceeded) {
            Write-Log "Validation attempt $retryCount failed: GitHub Desktop not found or version does not meet minimum requirements. Retrying in $DelayBetweenRetries seconds..." -Level "ERROR"
            Start-Sleep -Seconds $DelayBetweenRetries
        }
    }

    return @{IsInstalled = $false}
}



# # Example usage with splatting
# $validationParams = @{
#     RegistryPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubDesktop"
#     MinVersion          = [version]"3.4.3"
#     MaxRetries          = 3
#     DelayBetweenRetries = 5  # Delay in seconds
# }

# $validationResult = Validate-GitHubDesktopInstallation -Params $validationParams




function Install-GitHubDesktop {
    $totalSteps = 6
    $completedSteps = 0
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'GitHubDesktop.exe')
    $downloadUrl = 'https://central.github.com/deployments/desktop/desktop/latest/win32'

    # Step 1: Pre-installation validation
    Write-Log "Step 1: Validating existing installation of GitHub Desktop..."
    
    $preValidationParams = @{
        RegistryPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubDesktop"
        MinVersion          = [version]"3.4.3"
        MaxRetries          = 3
        DelayBetweenRetries = 5  # Delay in seconds
    }
    $preInstallCheck = Validate-GitHubDesktopInstallation @preValidationParams
    
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
    
    $postValidationParams = @{
        RegistryPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubDesktop"
        MinVersion          = [version]"3.4.3"
        MaxRetries          = 3
        DelayBetweenRetries = 5  # Delay in seconds
    }
    
    $postInstallCheck = Validate-GitHubDesktopInstallation @postValidationParams
    if ($postInstallCheck.IsInstalled) {
        Write-Log "Validation successful: GitHub Desktop version $($postInstallCheck.Version) is installed."
        $completedSteps++
    } else {
        Write-Log "Validation failed after $($postValidationParams['MaxRetries']) attempts: GitHub Desktop was not found on the system." -Level "ERROR"
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
    if ($postInstallCheck.IsInstalled) {
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