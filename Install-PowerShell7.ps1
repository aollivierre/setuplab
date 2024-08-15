# Install-PowerShell7.ps1

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-PowerShell7.log')
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

function CheckAndElevate {
    <#
    .SYNOPSIS
    Checks if the script is running with administrative privileges and optionally elevates it if not.

    .DESCRIPTION
    The CheckAndElevate function checks whether the current PowerShell session is running with administrative privileges. 
    It can either return the administrative status or attempt to elevate the script if it is not running as an administrator.

    .PARAMETER ElevateIfNotAdmin
    If set to $true, the function will attempt to elevate the script if it is not running with administrative privileges. 
    If set to $false, the function will simply return the administrative status without taking any action.

    .EXAMPLE
    CheckAndElevate -ElevateIfNotAdmin $true

    Checks the current session for administrative privileges and elevates if necessary.

    .EXAMPLE
    $isAdmin = CheckAndElevate -ElevateIfNotAdmin $false
    if (-not $isAdmin) {
        Write-Host "The script is not running with administrative privileges."
    }

    Checks the current session for administrative privileges and returns the status without elevating.
    
    .NOTES
    If the script is elevated, it will restart with administrative privileges. Ensure that any state or data required after elevation is managed appropriately.
    #>

    [CmdletBinding()]
    param (
        [bool]$ElevateIfNotAdmin = $true
    )

    Begin {
        Write-Log -Message "Starting CheckAndElevate function" -Level "NOTICE"

        # Use .NET classes for efficiency
        try {
            $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            Write-Log -Message "Checking for administrative privileges..." -Level "INFO"
        }
        catch {
            Write-Log -Message "Error determining administrative status: $($_.Exception.Message)" -Level "ERROR"
            Handle-Error -ErrorRecord $_
            throw $_
        }
    }

    Process {
        if (-not $isAdmin) {
            if ($ElevateIfNotAdmin) {
                try {
                    Write-Log -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING"

                    $powerShellPath = Get-PowerShellPath
                    $startProcessParams = @{
                        FilePath     = $powerShellPath
                        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
                        Verb         = "RunAs"
                    }
                    Start-Process @startProcessParams

                    Write-Log -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO"
                    exit
                }
                catch {
                    Write-Log -Message "Failed to elevate privileges: $($_.Exception.Message)" -Level "ERROR"
                    Handle-Error -ErrorRecord $_
                    throw $_
                }
            }
            else {
                Write-Log -Message "The script is not running with administrative privileges and will continue without elevation." -Level "INFO"
            }
        }
        else {
            Write-Log -Message "Script is already running with administrative privileges." -Level "INFO"
        }
    }

    End {
        Write-Log -Message "Exiting CheckAndElevate function" -Level "NOTICE"
        return $isAdmin
    }
}

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
                            $installedVersion = [version]$app.DisplayVersion.Split(" ")[0]  # Extract only the version number
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
                                $installedVersion = [version]$app.DisplayVersion.Split(" ")[0]  # Extract only the version number
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
                    $appVersion = [version]$appVersionString

                    if ($appVersion -ge $MinVersion) {
                        Write-Log -Message "Validation successful: $SoftwareName version $appVersion is installed at $ExePath." -Level "INFO"
                        return @{
                            IsInstalled = $true
                            Version     = $appVersion
                            Path        = $ExePath
                        }
                    }
                    else {
                        Write-Log -Message "Validation failed: $SoftwareName version $appVersion does not meet the minimum version requirement ($MinVersion)." -Level "WARNING"
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


function Start-FileDownloadWithRetry {

    <#
    .SYNOPSIS
        Downloads a file from a specified URL with retry logic. Falls back to using WebClient if BITS transfer fails.

    .DESCRIPTION
        This function attempts to download a file from a specified source URL to a destination path using BITS (Background Intelligent Transfer Service). 
        If BITS fails after a specified number of retries, the function falls back to using the .NET WebClient class for the download.

    .PARAMETER Source
        The URL of the file to download.

    .PARAMETER Destination
        The file path where the downloaded file will be saved.

    .PARAMETER MaxRetries
        The maximum number of retry attempts if the download fails. Default is 3.

    .EXAMPLE
        Start-FileDownloadWithRetry -Source "https://example.com/file.zip" -Destination "C:\Temp\file.zip"

    .NOTES
        Author: Abdullah Ollivierre
        Date: 2024-08-15
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    Begin {
        Write-Log -Message "Starting Start-FileDownloadWithRetry function" -Level "NOTICE"
        # # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters

        # Ensure the destination folder exists, create it if necessary
        $destinationFolder = Split-Path -Path $Destination -Parent
        if (-not (Test-Path -Path $destinationFolder)) {
            Write-Log -Message "Destination folder does not exist. Creating folder: $destinationFolder" -Level "INFO"
            New-Item -Path $destinationFolder -ItemType Directory | Out-Null
        }
    }

    Process {
        $attempt = 0
        $success = $false

        while ($attempt -lt $MaxRetries -and -not $success) {
            try {
                $attempt++
                Write-Log -Message "Attempt $attempt to download from $Source to $Destination" -Level "INFO"

                if (-not (Test-Path -Path $destinationFolder)) {
                    throw "Destination folder does not exist: $destinationFolder"
                }

                # Attempt download using BITS
                $bitsTransferParams = @{
                    Source      = $Source
                    Destination = $Destination
                    ErrorAction = "Stop"
                }
                Start-BitsTransfer @bitsTransferParams

                # Validate file existence and size after download
                if (Test-Path $Destination) {
                    $fileInfo = Get-Item $Destination
                    if ($fileInfo.Length -gt 0) {
                        Write-Log -Message "Download successful using BITS on attempt $attempt. File size: $($fileInfo.Length) bytes" -Level "INFO"
                        $success = $true
                    }
                    else {
                        Write-Log -Message "Download failed: File is empty after BITS transfer." -Level "ERROR"
                        throw "Download failed due to empty file after BITS transfer."
                    }
                }
                else {
                    Write-Log -Message "Download failed: File not found after BITS transfer." -Level "ERROR"
                    throw "Download failed due to missing file after BITS transfer."
                }

            }
            catch {
                Write-Log -Message "BITS transfer failed on attempt $attempt $($_.Exception.Message)" -Level "ERROR"
                if ($attempt -eq $MaxRetries) {
                    Write-Log -Message "Maximum retry attempts reached. Falling back to WebClient for download." -Level "WARNING"
                    try {
                        $webClient = [System.Net.WebClient]::new()
                        $webClient.DownloadFile($Source, $Destination)
                    
                        # Validate file existence and size after download
                        if (Test-Path $Destination) {
                            $fileInfo = Get-Item $Destination
                            if ($fileInfo.Length -gt 0) {
                                Write-Log -Message "Download successful using WebClient. File size: $($fileInfo.Length) bytes" -Level "INFO"
                                $success = $true
                            }
                            else {
                                Write-Log -Message "Download failed: File is empty after WebClient download." -Level "ERROR"
                                throw "Download failed due to empty file after WebClient download."
                            }
                        }
                        else {
                            Write-Log -Message "Download failed: File not found after WebClient download." -Level "ERROR"
                            throw "Download failed due to missing file after WebClient download."
                        }
                    }
                    catch {
                        Write-Log -Message "WebClient download failed: $($_.Exception.Message)" -Level "ERROR"
                        throw "Download failed after multiple attempts using both BITS and WebClient."
                    }
                    
                }
                else {
                    Start-Sleep -Seconds 5
                }
            }
        }
    }

    End {
        Write-Log -Message "Exiting Start-FileDownloadWithRetry function" -Level "NOTICE"
    }
}


function Install-PowerShell7 {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # Parameters for validating PowerShell installation
    $validationParams = @{
        SoftwareName        = "PowerShell"
        MinVersion          = [version]"7.4.4"
        RegistryPath        = "HKLM:\SOFTWARE\Microsoft\PowerShellCore"
        ExePath             = "C:\Program Files\PowerShell\7\pwsh.exe"
        MaxRetries          = 3
        DelayBetweenRetries = 5
    }

    # Perform the initial validation
    $validationResult = Validate-SoftwareInstallation @validationParams

    # Skip installation if already validated
    if ($validationResult.IsInstalled) {
        Write-Log -Message "PowerShell version $($validationResult.Version) is already installed and validated." -Level "INFO"
        exit 0
    }

    try {
        Write-Log -Message "Fetching the latest PowerShell release info..." -Level "INFO"
        $restMethodParams = @{
            Uri     = 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
            Headers = @{ 'User-Agent' = 'PowerShell' }
        }
        $latestRelease = Invoke-RestMethod @restMethodParams
        $url = $latestRelease.assets | Where-Object { $_.name -like '*win-x64.msi' } | Select-Object -ExpandProperty browser_download_url
        Write-Log -Message "Latest PowerShell MSI URL found: $url" -Level "INFO"
    }
    catch {
        Write-Log -Message "Error fetching the latest PowerShell release info: $_" -Level "ERROR"
        exit 1
    }

    # Generate a timestamped folder within the TEMP directory
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $installerPath = [System.IO.Path]::Combine($env:TEMP, "pwsh_$timestamp", 'pwsh.msi')

    # Set up the parameters for downloading PowerShell MSI
    $downloadParams = @{
        Source      = $url
        Destination = $installerPath
        MaxRetries  = 3
    }

    try {
        Write-Log -Message "Downloading PowerShell from $url..." -Level "INFO"
        Start-FileDownloadWithRetry @downloadParams
        Write-Log -Message "Download complete." -Level "INFO"
    }
    catch {
        Write-Log -Message "Error downloading PowerShell: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log -Message "Installing PowerShell..." -Level "INFO"
        $msiParams = "/i $installerPath /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"
        $startProcessParams = @{
            FilePath     = 'msiexec.exe'
            ArgumentList = $msiParams
            Wait         = $true
            PassThru     = $true
        }
        $installProcess = Start-Process @startProcessParams

        if ($installProcess.ExitCode -eq 0) {
            Write-Log -Message "PowerShell installation completed successfully." -Level "INFO"
        }
        else {
            Write-Log -Message "PowerShell installation failed. Exit code: $($installProcess.ExitCode)" -Level "ERROR"
            exit 1
        }
    }
    catch {
        Write-Log -Message "Error installing PowerShell: $_" -Level "ERROR"
        exit 1
    }

    # Perform post-installation validation
    $postValidationResult = Validate-SoftwareInstallation @validationParams

    if ($postValidationResult.IsInstalled -and $postValidationResult.Version -ge $validationParams.MinVersion) {
        Write-Log -Message "PowerShell version $($postValidationResult.Version) successfully installed and validated." -Level "INFO"
    }
    else {
        Write-Log -Message "Post-installation validation failed. PowerShell was not installed correctly." -Level "ERROR"
        exit 1
    }

    Write-Log -Message "PowerShell installation process completed." -Level "INFO"
    exit 0
}

# Elevate to administrator if not already
CheckAndElevate -ElevateIfNotAdmin $true

# Call the Install-PowerShell7 function
Install-PowerShell7