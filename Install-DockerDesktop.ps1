# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function for logging with color coding
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        default { Write-Host $logMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-DockerDesktop.log')
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

function Sanitize-VersionString {
    param (
        [string]$versionString
    )

    try {
        # Remove any non-numeric characters and additional segments like ".windows"
        $sanitizedVersion = $versionString -replace '[^0-9.]', '' -replace '\.\.+', '.'

        # Convert to System.Version
        $version = [version]$sanitizedVersion
        return $version
    }
    catch {
        Write-EnhancedLog -Message "Failed to convert version string: $versionString. Error: $_" -Level "ERROR"
        return $null
    }
}

# Function to validate the installation of Docker Desktop with splat parameters
function Validate-SoftwareInstallation {
    [CmdletBinding()]
    param (
        [string]$SoftwareName,
        [version]$MinVersion = [version]"0.0.0.0",
        [string]$RegistryPath = "",
        [string]$ExePath = "",
        [int]$MaxRetries = 3,
        [int]$DelayBetweenRetries = 5
    )

    Begin {
        Write-Log -Message "Starting Validate-SoftwareInstallation function" -Level "NOTICE"
        # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    }

    Process {
        $retryCount = 0
        $validationSucceeded = $false

        while ($retryCount -lt $MaxRetries -and -not $validationSucceeded) {
            # Registry-based validation
            if ($RegistryPath -or $SoftwareName) {
                $registryPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                )

                if ($RegistryPath) {
                    if (Test-Path $RegistryPath) {
                        $app = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
                        if ($app -and $app.DisplayName -like "*$SoftwareName*") {
                            $installedVersion = Sanitize-VersionString -versionString $app.DisplayVersion
                            if ($installedVersion -ge $MinVersion) {
                                $validationSucceeded = $true
                                return @{
                                    IsInstalled = $true
                                    Version     = $installedVersion
                                    ProductCode = $app.PSChildName
                                }
                            }
                        }
                    }
                }
                else {
                    foreach ($path in $registryPaths) {
                        $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                        foreach ($item in $items) {
                            $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
                            if ($app.DisplayName -like "*$SoftwareName*") {
                                $installedVersion = Sanitize-VersionString -versionString $app.DisplayVersion
                                if ($installedVersion -ge $MinVersion) {
                                    $validationSucceeded = $true
                                    return @{
                                        IsInstalled = $true
                                        Version     = $installedVersion
                                        ProductCode = $app.PSChildName
                                    }
                                }
                            }
                        }
                    }
                }
            }

            # File-based validation
            if ($ExePath) {
                if (Test-Path $ExePath) {
                    $appVersionString = (Get-ItemProperty -Path $ExePath).VersionInfo.ProductVersion.Split(" ")[0]  # Extract only the version number
                    $appVersion = Sanitize-VersionString -versionString $appVersionString

                    if ($appVersion -ge $MinVersion) {
                        Write-Log -Message "Validation successful: $SoftwareName version $appVersion is installed at $ExePath." -Level "INFO"
                        return @{
                            IsInstalled = $true
                            Version     = $appVersion
                            Path        = $ExePath
                        }
                    }
                    else {
                        Write-Log -Message "Validation failed: $SoftwareName version $appVersion does not meet the minimum version requirement ($MinVersion)." -Level "ERROR"
                    }
                }
                else {
                    Write-Log -Message "Validation failed: $SoftwareName executable was not found at $ExePath." -Level "ERROR"
                }
            }

            $retryCount++
            Write-Log -Message "Validation attempt $retryCount failed: $SoftwareName not found or version does not meet the minimum requirement ($MinVersion). Retrying in $DelayBetweenRetries seconds..." -Level "WARNING"
            Start-Sleep -Seconds $DelayBetweenRetries
        }

        return @{ IsInstalled = $false }
    }

    End {
        Write-Log -Message "Exiting Validate-SoftwareInstallation function" -Level "NOTICE"
    }
}




# # Parameters for validating OneDrive installation
# $oneDriveValidationParams = @{
#     SoftwareName         = "OneDrive"
#     MinVersion           = [version]"24.146.0721.0003"  # Example minimum version
#     RegistryPath         = "HKLM:\SOFTWARE\Microsoft\OneDrive"  # Example registry path for OneDrive metadata
#     ExePath              = "C:\Program Files\Microsoft OneDrive\OneDrive.exe"  # Path to the OneDrive executable
#     MaxRetries           = 3
#     DelayBetweenRetries  = 5
# }

# # Perform the validation
# $oneDriveValidationResult = Validate-SoftwareInstallation @oneDriveValidationParams

# # Check the results of the validation
# if ($oneDriveValidationResult.IsInstalled) {
#     Write-Host "OneDrive version $($oneDriveValidationResult.Version) is installed and validated." -ForegroundColor Green
#     Write-Host "Executable Path: $($oneDriveValidationResult.Path)"
# } else {
#     Write-Host "OneDrive is not installed or does not meet the minimum version requirement." -ForegroundColor Red
# }




# Function to install Docker Desktop using Windows Containers
function Install-DockerDesktop {
    $totalSteps = 6
    $completedSteps = 0
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'DockerDesktopInstaller.exe')
    $downloadUrl = 'https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe'

    # Step 1: Pre-installation validation
    Write-Log "Step 1: Validating existing installation of Docker Desktop..."
    
    $preValidationParams = @{
        SoftwareName        = "Docker Desktop"
        MinVersion          = [version]"4.34.2"  # Adjust the required minimum version
        RegistryPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Docker Desktop"
        MaxRetries          = 3
        DelayBetweenRetries = 5  # Delay in seconds
    }
    $preInstallCheck = Validate-SoftwareInstallation @preValidationParams
    
    if ($preInstallCheck.IsInstalled) {
        Write-Log "Docker Desktop version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "Docker Desktop is not currently installed." -Level "INFO"
    }
    $completedSteps++

    # Step 2: Downloading Docker Desktop
    Write-Log "Step 2: Downloading Docker Desktop from $downloadUrl..."
    try {
        Start-BitsTransferWithRetry -Source $downloadUrl -Destination $installerPath
        Write-Log 'Download complete.'
    }
    catch {
        Write-Log "Error downloading Docker Desktop: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    Write-Log "Installer path: $installerPath"

    # Step 3: Installing Docker Desktop using command line with Windows Containers
    Write-Log "Step 3: Installing Docker Desktop with Windows Containers..."
    try {
        # Use the correct command-line arguments for Docker Desktop installation
        $arguments = @('install', '--accept-license', '--quiet', '--backend=windows')
        Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru
        Write-Log 'Installation complete.'
    }
    catch {
        Write-Log "Error installing Docker Desktop: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++

    # Step 4: Post-installation validation
    Write-Log "Step 4: Validating Docker Desktop installation..."
    
    $postValidationParams = @{
        SoftwareName        = "Docker Desktop"
        MinVersion          = [version]"4.34.2"
        RegistryPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Docker Desktop"
        MaxRetries          = 3
        DelayBetweenRetries = 5
    }
    
    $postInstallCheck = Validate-SoftwareInstallation @postValidationParams
    if ($postInstallCheck.IsInstalled) {
        Write-Log "Validation successful: Docker Desktop version $($postInstallCheck.Version) is installed."
        $completedSteps++
    } else {
        Write-Log "Validation failed after $($postValidationParams['MaxRetries']) attempts: Docker Desktop was not found on the system." -Level "ERROR"
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
        Write-Host "Docker Desktop was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-DockerDesktop function
Install-DockerDesktop
