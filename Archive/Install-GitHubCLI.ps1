# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'Clone-EnhancedRepos.log')
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

function Get-LatestGitHubCLIInstallerUrl {
    <#
    .SYNOPSIS
    Gets the latest GitHub CLI Windows amd64 installer URL.

    .DESCRIPTION
    This function retrieves the URL for the latest GitHub CLI Windows amd64 installer from the GitHub releases page.

    .PARAMETER releasesUrl
    The URL for the GitHub CLI releases page.

    .EXAMPLE
    Get-LatestGitHubCLIInstallerUrl -releasesUrl "https://api.github.com/repos/cli/cli/releases/latest"
    Retrieves the latest GitHub CLI Windows amd64 installer URL.

    .NOTES
    This function requires an internet connection to access the GitHub API.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$releasesUrl
    )

    begin {
        Write-Log -Message "Starting Get-LatestGitHubCLIInstallerUrl function" -Level "Notice"
        # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    }

    process {
        try {
            $headers = @{
                "User-Agent" = "Mozilla/5.0"
            }

            $response = Invoke-RestMethod -Uri $releasesUrl -Headers $headers

            foreach ($asset in $response.assets) {
                if ($asset.name -match "windows_amd64.msi") {
                    return $asset.browser_download_url
                }
            }

            throw "Windows amd64 installer not found."
        } catch {
            Write-Log -Message "Error retrieving installer URL: $_" -Level "ERROR"
            # Handle-Error -ErrorRecord $_
            throw $_
        }
    }

    end {
        Write-Log -Message "Get-LatestGitHubCLIInstallerUrl function execution completed." -Level "Notice"
    }
}

# Function to get PowerShell path
function Get-PowerShellPath {
    if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
        return "C:\Program Files\PowerShell\7\pwsh.exe"
    }
    elseif (Test-Path "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") {
        return "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    }
    else {
        throw "Neither PowerShell 7 nor PowerShell 5 was found on this system."
    }
}


function Validate-ApplicationInstallation {
    param (
        [string]$AppDisplayName,
        [version]$MinVersion = [version]"2.54.0",
        [int]$MaxRetries = 3,
        [int]$DelayBetweenRetries = 5  # Delay in seconds
    )

    $retryCount = 0
    $validationSucceeded = $false

    while ($retryCount -lt $MaxRetries -and -not $validationSucceeded) {
        try {
            $registryPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"  # Include HKCU for user-installed apps
            )

            foreach ($path in $registryPaths) {
                $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
                    if ($app.DisplayName -like "*$AppDisplayName*") {
                        $installedVersion = [version]$app.DisplayVersion
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
        } catch {
            Write-Log "Error validating $AppDisplayName installation: $_" -Level "ERROR"
        }

        $retryCount++
        if (-not $validationSucceeded) {
            Write-Log "Validation attempt $retryCount failed: $AppDisplayName not found or version does not meet minimum requirements. Retrying in $DelayBetweenRetries seconds..." -Level "WARNING"
            Start-Sleep -Seconds $DelayBetweenRetries
        }
    }

    return @{IsInstalled = $false }
}



function Download-File {
    <#
    .SYNOPSIS
    Downloads a file from a given URL using WebClient.

    .DESCRIPTION
    This function downloads a file from the specified URL and saves it to the given path using the WebClient class for faster downloads. It includes a retry mechanism with configurable retries and delay.

    .PARAMETER Url
    The URL of the file to download.

    .PARAMETER OutputPath
    The local path where the file should be saved.

    .PARAMETER MaxRetries
    The maximum number of retry attempts in case of failure.

    .PARAMETER DelayBetweenRetries
    The delay between retry attempts, in seconds.

    .EXAMPLE
    Download-File -Url "https://example.com/file.msi" -OutputPath "$env:TEMP\file.msi"
    Downloads the file and saves it to the specified path.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$DelayBetweenRetries = 5  # Delay in seconds
    )

    begin {
        Write-Log -Message "Starting Download-File function" -Level "Notice"
    }

    process {
        $retryCount = 0
        $downloadSucceeded = $false

        while ($retryCount -lt $MaxRetries -and -not $downloadSucceeded) {
            try {
                Write-Log -Message "Attempting to download file from $Url to $OutputPath... (Attempt $($retryCount + 1))" -Level "INFO"
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($Url, $OutputPath)
                Write-Log -Message "Download completed successfully." -Level "INFO"
                $downloadSucceeded = $true
            } catch {
                $retryCount++
                Write-Log -Message "Error during file download: $_" -Level "ERROR"
                
                if ($retryCount -lt $MaxRetries) {
                    Write-Log -Message "Retrying download in $DelayBetweenRetries seconds... ($retryCount/$MaxRetries)" -Level "WARNING"
                    Start-Sleep -Seconds $DelayBetweenRetries
                } else {
                    Write-Log -Message "Max retries reached. Download failed." -Level "ERROR"
                    throw $_
                }
            }
        }
    }

    end {
        Write-Log -Message "Download-File function execution completed." -Level "Notice"
    }
}


function Install-GitHubCLI {
    <#
    .SYNOPSIS
    Installs the GitHub CLI on Windows.

    .DESCRIPTION
    This function installs the latest GitHub CLI Windows amd64 installer. It also verifies the installation in the same PowerShell session.

    .PARAMETER releasesUrl
    The URL for the GitHub CLI releases page.

    .PARAMETER installerPath
    The local path to save the installer.

    .EXAMPLE
    Install-GitHubCLI -releasesUrl "https://api.github.com/repos/cli/cli/releases/latest" -installerPath "$env:TEMP\gh_cli_installer.msi"
    Installs the latest GitHub CLI.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$releasesUrl,
        [Parameter(Mandatory = $true)]
        [string]$installerPath
    )

    begin {
        Write-Log -Message "Starting Install-GitHubCLI function" -Level "Notice"
    }

    process {
        try {
            # Pre-validation: Check if GitHub CLI is already installed and meets the minimum version
            $minVersion = [version]"2.54.0"
            $preValidationResult = Validate-ApplicationInstallation -AppDisplayName "GitHub CLI" -MinVersion $minVersion
            if ($preValidationResult.IsInstalled) {
                Write-Log -Message "GitHub CLI is already installed and meets the minimum version. Version: $($preValidationResult.Version)" -Level "INFO"
                return
            }

            # Get the latest installer URL
            $installerUrl = Get-LatestGitHubCLIInstallerUrl -releasesUrl $releasesUrl

            # Download the installer using the Download-File function
            Download-File -Url $installerUrl -OutputPath $installerPath

            # Install the GitHub CLI
            Write-Log -Message "Running the GitHub CLI installer..." -Level "INFO"
            $msiArgs = @(
                "/i"
                $installerPath
                "/quiet"
                "/norestart"
            )
            Start-Process msiexec.exe -ArgumentList $msiArgs -NoNewWindow -Wait

            # Post-validation: Verify the installation by calling Validate-GitHubCLIInstallation
            Write-Log -Message "Verifying the GitHub CLI installation..." -Level "INFO"
            $postValidationResult = Validate-ApplicationInstallation -AppDisplayName "GitHub CLI" -MinVersion $minVersion
            if ($postValidationResult.IsInstalled) {
                Write-Log -Message "GitHub CLI installed successfully. Version: $($postValidationResult.Version)" -Level "INFO"
            } else {
                Write-Log -Message "GitHub CLI installation failed or does not meet the minimum version requirement." -Level "ERROR"
                throw "GitHub CLI installation validation failed."
            }
        } catch {
            Write-Log -Message "Error during GitHub CLI installation: $_" -Level "ERROR"
            throw $_
        }
    }

    end {
        Write-Log -Message "Install-GitHubCLI function execution completed." -Level "Notice"
    }
}


# Define the URL for the GitHub CLI releases page
$githubCLIReleasesUrl = "https://api.github.com/repos/cli/cli/releases/latest"

# Define the local path to save the installer
$installerPath = "$env:TEMP\gh_cli_installer.msi"

# Example invocation to install GitHub CLI:
Install-GitHubCLI -releasesUrl $githubCLIReleasesUrl -installerPath $installerPath