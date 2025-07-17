# Install-Git.ps1

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
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "NOTICE" { Write-Host $logMessage -ForegroundColor Blue }
        default { Write-Host $logMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'Install-Git.log')
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
            Start-BitsTransfer -Source $Source -Destination $Destination -ErrorAction Stop
            $success = $true
        }
        catch {
            Write-Log "Attempt $attempt failed: $_" -Level "ERROR"
            if ($attempt -eq $MaxRetries) {
                throw "Maximum retry attempts reached."
            }
            Start-Sleep -Seconds 5
        }
    }
}

function Get-LatestGitUrl {
    try {
        Write-Log 'Fetching latest Git version URL...'
        $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
        }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        $installerUrl = $response.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -ExpandProperty browser_download_url
        if (-not $installerUrl) {
            throw "Could not find the download URL for the latest Git version."
        }
        Write-Log "Latest Git version URL found: $installerUrl"
        return $installerUrl
    }
    catch {
        Write-Log "Error fetching latest Git version URL: $_" -Level "ERROR"
        exit 1
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
        Write-Log -Message "Failed to convert version string: $versionString. Error: $_" -Level "ERROR"
        return $null
    }
}


function Install-Git {
    $downloadUrl = Get-LatestGitUrl
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Git-Installer.exe')
    $minGitVersion = [version]"2.46.0"
    $gitRegistryPath = "HKLM:\SOFTWARE\GitForWindows"
    $gitExePath = "C:\Program Files\Git\bin\git.exe"

    # Pre-validation: Check if Git is already installed and meets the minimum version
    $preValidationResult = Validate-SoftwareInstallation -SoftwareName "Git" -MinVersion $minGitVersion -RegistryPath $gitRegistryPath -ExePath $gitExePath
    if ($preValidationResult.IsInstalled) {
        Write-Log "Git is already installed and meets the minimum version. Version: $($preValidationResult.Version)" -Level "INFO"
        return
    }

    try {
        Write-Log 'Downloading Git...' -Level "INFO"
        $bitsTransferParams = @{
            Source      = $downloadUrl
            Destination = $installerPath
        }
        Start-BitsTransferWithRetry @bitsTransferParams
        Write-Log 'Download complete.' -Level "INFO"
    }
    catch {
        Write-Log "Error downloading Git: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    Write-Log "Installer path: $installerPath" -Level "INFO"

    try {
        Write-Log 'Installing Git...' -Level "INFO"
        $startProcessParams = @{
            FilePath     = $installerPath
            ArgumentList = '/SILENT'
            Wait         = $true
        }
        Start-Process @startProcessParams
        Write-Log 'Installation complete.' -Level "INFO"
    }
    catch {
        Write-Log "Error installing Git: $_" -Level "ERROR"
        Read-Host 'Press Enter to close this window...'
        exit 1
    }

    # Post-validation: Verify the installation by calling Validate-SoftwareInstallation again
    $postValidationResult = Validate-SoftwareInstallation -SoftwareName "Git" -MinVersion $minGitVersion -RegistryPath $gitRegistryPath -ExePath $gitExePath
    if ($postValidationResult.IsInstalled) {
        Write-Log "Git installed successfully. Version: $($postValidationResult.Version)" -Level "INFO"
    }
    else {
        Write-Log "Git installation failed or does not meet the minimum version requirement." -Level "ERROR"
        exit 1
    }

    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Git function
Install-Git

